\name{aws.script.wait}
\alias{aws.script.wait}
%- Also NEED an '\alias' for EACH other topic documented here.
\title{
%%  ~~function to do ... ~~
}
\description{
%%  ~~ A concise (1-5 lines) description of what the function does. ~~
}
\usage{
aws.script.wait(cl, s, verb = TRUE, mon.sec = 5)
}
%- maybe also 'usage' for other objects documented here.
\arguments{
  \item{cl}{
%%     ~~Describe \code{cl} here~~
}
  \item{s}{
%%     ~~Describe \code{s} here~~
}
  \item{verb}{
%%     ~~Describe \code{verb} here~~
}
  \item{mon.sec}{
%%     ~~Describe \code{mon.sec} here~~
}
}
\details{
%%  ~~ If necessary, more details than the description above ~~
}
\value{
%%  ~Describe the value returned
%%  If it is a LIST, use
%%  \item{comp1 }{Description of 'comp1'}
%%  \item{comp2 }{Description of 'comp2'}
%% ...
}
\references{
%% ~put references to the literature/web site here ~
}
\author{
%%  ~~who you are~~
}
\note{
%%  ~~further notes~~
}

%% ~Make other sections like Warning with \section{Warning }{....} ~

\seealso{
%% ~~objects to See Also as \code{\link{help}}, ~~~
}
\examples{
##---- Should be DIRECTLY executable !! ----
##-- ==>  Define data, use random,
##--	or do  help(data=index)  for the standard data sets.

## The function is currently defined as
function (cl, s, verb = TRUE, mon.sec = 5) 
{
    awsOpts <- options("mzaws")[[1]]
    checkIfStarted()
    if (!is(cl, "awsCluster")) 
        stop("cluster must be of class awsCluster")
    r <- presult(system(infuse("{{awscli}} emr describe-step --cluster-id {{ cid}} --step-id {{sid}}", 
        awscli = awsOpts$awscli, cid = cl$Id, sid = s), intern = TRUE))
    while (TRUE) {
        if (!is.null(r$Step$Status$Timeline$EndDateTime)) {
            ss <- r$Step$Status$State
            if (ss == "FAILED") 
                warning("the step failed")
            return(aws.clus.info(cl))
        }
        cat(".")
        if (verb) 
            Sys.sleep(mon.sec)
    }
  }
}
% Add one or more standard keywords, see file 'KEYWORDS' in the
% R documentation directory.
\keyword{ ~kwd1 }
\keyword{ ~kwd2 }% __ONLY ONE__ keyword per line
