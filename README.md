# GMVP Portfolio Optimization and Risk Analysis

## Overview

This project presents a comparative analysis of two portfolio allocation strategies:

- an equally weighted **1/N portfolio**,
- a long-only **Global Minimum Variance Portfolio (GMVP)**.

The objective of the project was to determine whether covariance-based portfolio optimization can reduce investment risk and improve portfolio performance compared with a simple equal-weighting strategy.

The analysis was conducted in **R** using historical daily stock prices for five companies representing different market sectors:

| Ticker | Sector |
|---|---|
| MSFT | Technology |
| AAL | Transportation |
| CVX | Energy |
| NKE | Consumer goods |
| COF | Financial services |

The strategies were evaluated through a rolling out-of-sample backtest using measures of return, volatility, downside risk, drawdown, and tail risk.

---

## Project Objectives

The main objectives of the project were to:

1. prepare and transform historical stock market data,
2. calculate daily logarithmic returns,
3. examine the statistical properties and dependencies between assets,
4. construct an equally weighted 1/N portfolio,
5. construct a long-only GMVP portfolio,
6. conduct rolling out-of-sample portfolio backtesting,
7. compare portfolio performance and risk,
8. select the preferred strategy using a weighted evaluation criterion.

---

## Research Question

The project addresses the following research question:

> Does a Global Minimum Variance Portfolio based on the covariance structure of assets reduce risk or improve risk-adjusted performance compared with a simple equally weighted portfolio in an out-of-sample rolling backtest?

---

## Portfolio Strategies

### 1. Equal-Weighted Portfolio — 1/N

The 1/N strategy allocates the same proportion of capital to every asset included in the portfolio.

For a portfolio containing five companies, each asset receives a weight of:

```text
1 / 5 = 20%
```

This approach serves as the benchmark because it:

- is simple and transparent,
- does not require parameter estimation,
- avoids covariance estimation errors,
- provides automatic diversification,
- produces stable portfolio weights.

### 2. Global Minimum Variance Portfolio — GMVP

The Global Minimum Variance Portfolio determines asset weights by minimizing total portfolio variance.

The optimization problem is subject to the following constraints:

```text
Sum of portfolio weights = 1
Portfolio weights >= 0
```

The non-negative weight restriction means that short selling is not allowed.

The portfolio weights are calculated using the covariance matrix of historical asset returns and quadratic programming.

---

## Dataset

The analysis requires the following source file:

```text
all_stocks_5yr.csv
```

The original dataset contains daily stock market observations for multiple companies.

The analysis uses the following variables:

- `date` — trading date,
- `close` — closing stock price,
- `Name` — company ticker.

The R script filters the complete dataset to the following five tickers:

```text
MSFT
AAL
CVX
NKE
COF
```

The analysed data cover the period from February 2013 to February 2018.

### Data Availability

**The original source data file has not been shared or included in this repository.**

To reproduce the analysis, the user must obtain the `all_stocks_5yr.csv` file independently and place it in the location expected by the R script.

By default, the script reads the dataset using:

```r
raw_data <- read.csv(
  "all_stocks_5yr.csv",
  stringsAsFactors = FALSE
)
```

Therefore, the source file should be placed in the main project directory.

The expected local project structure is:

```text
gmvp-portfolio-risk-analysis/
├── all_stocks_5yr.csv
├── gmvp_portfolio_analysis.R
├── README.md
└── .gitignore
```

Because the source dataset is not distributed with the repository, the analysis cannot be fully reproduced until the required CSV file is added locally.

---

## Data Preparation

The data preparation process includes:

1. importing the source CSV file,
2. converting the `date` variable to the R `Date` format,
3. filtering observations to the selected five companies,
4. selecting closing stock prices,
5. transforming the data from long to wide format,
6. checking for missing price observations,
7. removing incomplete observations,
8. converting the dataset into an `xts` time-series object,
9. calculating logarithmic returns,
10. removing initial missing values created during return calculation.

Logarithmic returns are calculated as:

```text
r(t) = ln(P(t) / P(t-1))
```

where:

- `P(t)` is the current closing price,
- `P(t-1)` is the previous closing price.

---

## Exploratory Data Analysis

The exploratory data analysis includes:

- descriptive statistics,
- historical stock price visualization,
- missing-value analysis,
- correlation analysis,
- correlation matrix visualization,
- identification of observations exceeding three standard deviations,
- boxplots of logarithmic returns,
- rolling volatility analysis,
- inspection of volatility clustering.

### Descriptive Statistics

Descriptive statistics are calculated for the daily logarithmic returns of each selected company.

The analysis includes:

- minimum and maximum return,
- arithmetic mean,
- standard deviation,
- skewness,
- kurtosis,
- number of observations,
- number of missing values.

These statistics make it possible to compare the return distributions and risk characteristics of the selected assets.

### Correlation Analysis

The correlation matrix is used to evaluate relationships between stock returns.

Moderately positive correlations indicate that the selected assets are exposed to common market movements but do not move identically.

This creates potential diversification benefits and provides a basis for covariance-based portfolio optimization.

### Outlier Detection

Potential outliers are identified using the following condition:

```text
|x - mean(x)| > 3 × standard deviation
```

The presence of extreme observations is important because outliers may influence:

- covariance estimates,
- portfolio weights,
- volatility measurements,
- Value at Risk,
- Expected Shortfall.

### Volatility Clustering

A 21-day rolling standard deviation and the absolute returns of MSFT are used to illustrate volatility clustering.

Periods of relatively stable returns are followed by periods of substantially higher market volatility, indicating that financial market risk is not constant over time.

---

## Portfolio Construction

### Equal-Weighted Portfolio Function

The 1/N portfolio assigns an equal weight to every asset:

```r
get_weights_1N <- function(returns) {
  N <- ncol(returns)
  return(rep(1 / N, N))
}
```

For five assets, the resulting weights are:

```text
MSFT: 20%
AAL:  20%
CVX:  20%
NKE:  20%
COF:  20%
```

### GMVP Function

The GMVP model minimizes portfolio variance using the covariance matrix of historical returns.

The optimization is performed with the `solve.QP()` function from the `quadprog` package.

The model includes the following constraints:

- the portfolio weights must sum to 1,
- all weights must be non-negative,
- short selling is not allowed.

A small value is added to the diagonal of the covariance matrix to improve numerical stability.

---

## Backtesting Methodology

Portfolio performance is evaluated using a rolling walk-forward backtest.

### Estimation Window

```text
252 trading days
```

This corresponds approximately to one year of stock market observations.

### Rebalancing Period

```text
22 trading days
```

This corresponds approximately to one trading month.

### Backtesting Process

For every rolling window:

1. the previous 252 observations are used as training data,
2. the covariance matrix is estimated from the training period,
3. the GMVP weights are calculated,
4. the 1/N weights remain fixed at 20% per asset,
5. both strategies are evaluated on the following 22 observations,
6. the estimation window is moved forward by 22 trading days,
7. the procedure is repeated until the end of the dataset.

This methodology ensures that portfolio weights are based only on information available before the test period.

It therefore reduces the risk of:

- look-ahead bias,
- in-sample overfitting,
- using future information during portfolio construction.

---

## Performance and Risk Metrics

The portfolio strategies are compared using the following measures.

### Annualized Return

Annualized return measures the portfolio return expressed on an annual basis.

It enables the performance of both strategies to be compared using a common yearly scale.

### Annualized Volatility

Annualized volatility measures the annualized standard deviation of portfolio returns.

Lower volatility indicates a more stable portfolio.

### Sharpe Ratio

The Sharpe ratio measures portfolio return relative to total risk.

```text
Sharpe Ratio = Annualized Return / Annualized Volatility
```

The risk-free rate was set to zero in the analysis.

A higher Sharpe ratio indicates better risk-adjusted performance.

### Maximum Drawdown

Maximum drawdown measures the largest decline in portfolio value from a historical peak to a subsequent trough.

A smaller maximum drawdown indicates better capital protection during adverse market conditions.

### Value at Risk — VaR

Historical Value at Risk at the 95% confidence level estimates the loss threshold associated with the worst 5% of daily portfolio returns.

### Expected Shortfall — ES

Expected Shortfall measures the average portfolio loss on days when the loss exceeds the VaR threshold.

Expected Shortfall therefore provides information about the severity of extreme losses.

---

## Results

The rolling out-of-sample analysis produced the following results:

| Metric | Equal-Weighted 1/N | GMVP |
|---|---:|---:|
| Annualized return | 11.79% | 8.16% |
| Annualized volatility | 16.85% | 15.67% |
| Sharpe ratio | 0.6995 | 0.5208 |
| Maximum drawdown | 23.54% | 20.71% |
| Historical VaR 95% | -1.69% | -1.63% |
| Historical ES 95% | -2.55% | -2.38% |

### Equal-Weighted Portfolio

The 1/N strategy achieved:

- a higher annualized return,
- a higher Sharpe ratio,
- better overall risk-adjusted performance,
- stable and transparent portfolio weights.

However, it was also associated with:

- higher annualized volatility,
- a larger maximum drawdown,
- slightly more severe tail losses.

### GMVP Portfolio

The GMVP strategy achieved:

- lower annualized volatility,
- a smaller maximum drawdown,
- slightly less negative Value at Risk,
- slightly less negative Expected Shortfall.

However, its reduction in risk was accompanied by:

- a lower annualized return,
- a lower Sharpe ratio,
- weaker overall return-to-risk efficiency.

---

## Model Selection Criterion

A weighted scoring system was used to select the preferred portfolio strategy.

The model score was based on rankings of:

- Sharpe ratio,
- maximum drawdown,
- Expected Shortfall.

The following weights were assigned:

| Evaluation component | Weight |
|---|---:|
| Sharpe ratio | 60% |
| Maximum drawdown | 30% |
| Expected Shortfall | 10% |

The final scores were:

| Strategy | Score |
|---|---:|
| Equal-Weighted 1/N | 1.6 |
| GMVP | 1.4 |

Based on this criterion, the **equal-weighted 1/N portfolio was selected as the preferred strategy**.

Its stronger Sharpe ratio and higher annualized return outweighed the moderate risk reduction achieved by GMVP.

---

## Main Conclusions

The analysis demonstrates a clear trade-off between portfolio return and portfolio risk.

The GMVP strategy successfully achieved its primary objective of reducing portfolio variance. It also produced a smaller maximum drawdown and slightly more favourable tail-risk measures.

However, these improvements were accompanied by a lower annualized return and a lower Sharpe ratio.

The equally weighted strategy generated better risk-adjusted performance in the analysed period.

It also offered practical advantages, including:

- constant portfolio weights,
- no dependency on covariance estimates,
- lower model complexity,
- easier interpretation,
- potentially lower portfolio turnover.

The results do not imply that one strategy is universally superior.

The appropriate strategy depends on the investor's objective:

- **1/N may be preferred when return and risk-adjusted performance are the main priorities.**
- **GMVP may be preferred when reducing volatility and limiting drawdowns are more important.**

---

## Technologies

The project was developed in:

- **R**
- **RStudio**

The analysis covers the following areas:

- financial data analysis,
- exploratory data analysis,
- time-series processing,
- portfolio optimization,
- quadratic programming,
- rolling backtesting,
- risk analysis,
- performance evaluation,
- data visualization.

---

## R Packages

The following packages are used:

```r
library(tidyverse)
library(quantmod)
library(PerformanceAnalytics)
library(corrplot)
library(reshape2)
library(quadprog)
```

### Package Purposes

- `tidyverse` — data filtering, transformation, and manipulation,
- `quantmod` — financial time-series tools,
- `PerformanceAnalytics` — portfolio performance and risk metrics,
- `corrplot` — correlation matrix visualization,
- `reshape2` — conversion from long to wide data format,
- `quadprog` — quadratic optimization for GMVP weights.

---

## Installation

Install the required packages in R:

```r
install.packages(
  c(
    "tidyverse",
    "quantmod",
    "PerformanceAnalytics",
    "corrplot",
    "reshape2",
    "quadprog"
  )
)
```

---



## Generated Outputs

The script generates:

- descriptive statistics for asset returns,
- missing-value summaries,
- historical stock price charts,
- a correlation matrix,
- a correlation heatmap,
- return boxplots,
- outlier counts,
- a rolling volatility chart,
- an absolute-return chart,
- out-of-sample portfolio return series,
- cumulative performance charts,
- annualized return metrics,
- annualized volatility metrics,
- Sharpe ratios,
- maximum drawdowns,
- historical VaR values,
- historical Expected Shortfall values,
- weighted strategy scores.

---

## Limitations

The results should be interpreted in the context of several limitations:

- the analysis covers only five selected companies,
- the analysed period covers 2013–2018,
- historical performance does not guarantee future results,
- transaction costs are not included,
- taxes and brokerage fees are not included,
- portfolio turnover costs are not modelled,
- dividends are not analysed separately,
- the covariance matrix is estimated using historical returns,
- covariance estimates may be sensitive to outliers,
- the model assumes that historical dependencies contain useful information about future risk,
- the original source dataset has not been shared or included in the repository.

The GMVP model may also produce unstable allocations when covariance estimates change significantly between estimation windows.


## Authors

This project was developed as an academic group project by:

- Joanna Jarosz
- Paulina Ryguła
- Zuzanna Zaręba
- Filip Bednorz


## Disclaimer

This project was created for educational and analytical purposes.

It does not constitute financial advice, an investment recommendation, or an offer to buy or sell financial instruments.

All investment decisions involve risk. Historical portfolio performance does not guarantee future results.

