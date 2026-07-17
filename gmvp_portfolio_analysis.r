#biblioteki
#install.packages("tidyverse")
#install.packages("quantmod")
#install.packages("PerformanceAnalytics")
#install.packages("corrplot")
#install.packages("reshape2")

#install.packages("quadprog")

library(tidyverse)
library(quantmod)
library(PerformanceAnalytics)
library(corrplot)
library(reshape2)
library(quadprog)

#wczytanie danych
raw_data <- read.csv("all_stocks_5yr.csv", stringsAsFactors = FALSE)

#konwersja daty
raw_data$date <- as.Date(raw_data$date)

#wybór 5 spółek z różnych sektorów
# MSFT (Tech), AAL (Transport), CVX (Energy), NKE (Consumer), COF (Finance)
tickers <- c("MSFT", "AAL", "CVX", "NKE", "COF")

df_subset <- raw_data %>%
  filter(Name %in% tickers) %>%
  select(date, Name, close)

#transformacja do formatu szerokiego
prices_wide <- dcast(df_subset, date ~ Name, value.var = "close")

#EDA o brakach danych (NA) w cenach
na_by_asset_prices <- colSums(is.na(prices_wide[, -1]))
print(na_by_asset_prices)
cat("Łącznie NA w tabeli cen:", sum(is.na(prices_wide[, -1])), "\n")

#usunięcie braków
prices_wide <- na.omit(prices_wide)

#konwersja na obiekt xts
prices_xts <- xts(prices_wide[,-1], order.by = prices_wide$date)

#obliczenie logarytmicznych stóp zwrotu
returns_xts_raw <- CalculateReturns(prices_xts, method = "log")

#EDA o brakach danych (NA) w zwrotach
na_by_asset_returns <- colSums(is.na(returns_xts_raw))
print(na_by_asset_returns)
cat("Łącznie NA w zwrotach:", sum(is.na(returns_xts_raw)), "\n")

#usunięcie braków
returns_xts <- na.omit(returns_xts_raw)

#Eksploracyjna analiza danych (EDA)
print(table.Stats(returns_xts))

#wizualizacja cen
chart.TimeSeries(prices_xts, main = "Ceny akcji (Historical)", legend.loc = "topleft")

#macierz korelacji
cor_matrix <- cor(returns_xts)
corrplot(cor_matrix, method = "color", type = "upper",
         addCoef.col = "black", tl.col = "black",
         title = "Macierz Korelacji Stóp Zwrotu", mar=c(0,0,1,0))

#outliers (odstające obserwacje)
outliers_3sd <- sapply(colnames(returns_xts), function(sym) {
  x <- as.numeric(returns_xts[, sym])
  sum(abs(x - mean(x)) > 3 * sd(x))
})
print(outliers_3sd)

#boxplot zwrotów 
chart.Boxplot(returns_xts, main = "Boxplot: log-returns (outliers/asymetria)")

#Heteroskedastyczność (zmienna zmienność w czasie)
#21-dniowa krocząca zmienność dla MSFT
example_ticker <- "MSFT"
roll_vol_21 <- rollapply(returns_xts[, example_ticker], width = 21, FUN = sd,
                         align = "right", fill = NA)
chart.TimeSeries(roll_vol_21, main = paste0("Rolling 21D volatility: ", example_ticker),
                 legend.loc = "topleft")

#klastry dla zwrotów
chart.TimeSeries(abs(returns_xts[, example_ticker]),
                 main = paste0("|Returns|: ", example_ticker, " (clustering zmienności)"),
                 legend.loc = "topleft")

#modele wielowymiarowe
#model 1 - strategia 1/n
get_weights_1N <- function(returns) {
  N <- ncol(returns)
  return(rep(1/N, N))
}

#GMVP bez wag ujemnych
get_weights_GMVP <- function(returns) {
  cov_mat <- cov(returns)
  n <- ncol(cov_mat)
  
  #stabilizacja numeryczna
  cov_mat <- cov_mat + diag(1e-6, n)
  
  Dmat <- 2 * cov_mat
  dvec <- rep(0, n)
  
  #ograniczenia w solve.QP mają postać: t(Amat) %*% w >= bvec
  Amat <- cbind(rep(1, n), diag(n))
  bvec <- c(1, rep(0, n))
  
  sol <- solve.QP(Dmat = Dmat, dvec = dvec, Amat = Amat, bvec = bvec, meq = 1)
  w <- sol$solution
  
  #poprawki numeryczne
  w[w < 0] <- 0
  w <- w / sum(w)
  
  return(as.vector(w))
}

#walidacja backtest
window_size <- 252       
rebalance_period <- 22   
n_obs <- nrow(returns_xts)

strategy_returns_1N <- c()
strategy_returns_GMVP <- c()

for (i in seq(window_size, n_obs - rebalance_period, by = rebalance_period)) {
  
  train_data <- returns_xts[(i - window_size + 1):i, ]
  
  w_1N <- get_weights_1N(train_data)
  w_GMVP <- get_weights_GMVP(train_data)
  
  test_data <- returns_xts[(i + 1):(i + rebalance_period), ]
  
  r_1N <- test_data %*% w_1N
  r_GMVP <- test_data %*% w_GMVP
  
  strategy_returns_1N <- c(strategy_returns_1N, r_1N)
  strategy_returns_GMVP <- c(strategy_returns_GMVP, r_GMVP)
}

#konwersja wyników na xts
test_dates <- index(returns_xts)[(window_size + 1):(window_size + length(strategy_returns_1N))]
portfolio_returns <- xts(cbind(strategy_returns_1N, strategy_returns_GMVP), order.by = test_dates)
colnames(portfolio_returns) <- c("Benchmark_1N", "Model_GMVP")

#porównanie modeli i analiza ryzyka
#wykres skumulowanych zwrotów (Equity Curve)
charts.PerformanceSummary(portfolio_returns,
                          main = "Porównanie Strategii: 1/N vs GMVP (Out-of-Sample)",
                          colorset = c("red", "blue"))

stats <- table.AnnualizedReturns(portfolio_returns, scale = 252, Rf = 0)
print(stats)

risk_stats <- table.DownsideRisk(portfolio_returns, p = 0.95)
print(risk_stats[c("Historical VaR (95%)", "Historical ES (95%)"), ])

#jasne kryterium wyboru modelu (score) + automatyczny wybór
#liczymy kluczowe metryki osobno
ann_ret <- sapply(1:ncol(portfolio_returns), function(j) as.numeric(Return.annualized(portfolio_returns[, j])))
ann_vol <- sapply(1:ncol(portfolio_returns), function(j) as.numeric(StdDev.annualized(portfolio_returns[, j])))
sharpe  <- sapply(1:ncol(portfolio_returns), function(j) as.numeric(SharpeRatio.annualized(portfolio_returns[, j], Rf = 0)))
mdd     <- sapply(1:ncol(portfolio_returns), function(j) as.numeric(maxDrawdown(portfolio_returns[, j])))

#var/ES (historyczne) – wartości zwykle ujemne
var95 <- sapply(1:ncol(portfolio_returns), function(j) as.numeric(VaR(portfolio_returns[, j], p = 0.95, method = "historical")))
es95  <- sapply(1:ncol(portfolio_returns), function(j) as.numeric(ES(portfolio_returns[, j],  p = 0.95, method = "historical")))

metrics_df <- data.frame(
  model = colnames(portfolio_returns),
  ann_return = ann_ret,
  ann_vol = ann_vol,
  sharpe = sharpe,
  maxDD = mdd,
  VaR_95 = var95,
  ES_95 = es95,
  row.names = NULL
)

print(metrics_df)

#score oparty o rankingi:
#sharpe - im wyżej tym lepiej
#maxDD - im mniej ujemny tym lepiej -> rank(-abs(maxDD))
#ES - im mniejszy ogon (mniej ujemny) tym lepiej -> rank(-abs(ES))
rank_sharpe <- rank(metrics_df$sharpe, ties.method = "average")               
rank_dd     <- rank(-abs(metrics_df$maxDD), ties.method = "average")            
rank_es     <- rank(-abs(metrics_df$ES_95), ties.method = "average")            

#kryterium wyboru
w_sh <- 0.6
w_dd <- 0.3
w_es <- 0.1

metrics_df$score <- w_sh*rank_sharpe + w_dd*rank_dd + w_es*rank_es

print(metrics_df[, c("model", "sharpe", "maxDD", "ES_95", "score")])

best_model <- metrics_df$model[which.max(metrics_df$score)]

#wnioski
sharpe_1N <- SharpeRatio.annualized(portfolio_returns[,1])
sharpe_GMVP <- SharpeRatio.annualized(portfolio_returns[,2])
std_GMVP <- StdDev.annualized(portfolio_returns[,2])
std_1N <- StdDev.annualized(portfolio_returns[,1])

print(sharpe_1N)
print(sharpe_GMVP)
print(std_GMVP)
print(std_1N)
