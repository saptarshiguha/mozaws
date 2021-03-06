% Generated by roxygen2 (4.1.0): do not edit by hand
% Please edit documentation in R/aws.r
\name{aws.clus.wait}
\alias{aws.clus.wait}
\title{Waits for the cluster to start}
\usage{
aws.clus.wait(clusters, mon.sec = 5, silent = FALSE)
}
\arguments{
\item{clusters}{is an object obtained from \code{aws.clus.create}}

\item{mon.sec}{polling interval}

\item{silent}{chatty?}
}
\value{
the cluster object. Save it.
}
\description{
Waits for the cluster to start
}
\examples{
\dontrun{
  s = aws.clus.wait(s)
}
}

