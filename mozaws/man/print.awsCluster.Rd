\name{print.awsCluster}
\alias{print.awsCluster}
%- Also NEED an '\alias' for EACH other topic documented here.
\title{
%%  ~~function to do ... ~~
}
\description{
%%  ~~ A concise (1-5 lines) description of what the function does. ~~
}
\usage{
print.awsCluster(r)
}
%- maybe also 'usage' for other objects documented here.
\arguments{
  \item{r}{
%%     ~~Describe \code{r} here~~
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
function (r) 
{
    state <- isn(r$Status$State, NA)
    name <- isn(r$Name)
    started <- as.POSIXct(isn(r$Status$Timeline$CreationDateTime), 
        origin = "1970-01-01")
    currently <- isn(r$Status$StateChangeReason$Message)
    dns <- isn(r$MasterPublicDnsName)
    master <- unlist(lapply(r$InstanceGroups, function(s) {
        if (s$Name == "MASTER") {
            data.table(type = s$InstanceType, running = s$RunningInstanceCount > 
                0)
        }
    }))
    workers.core <- do.call(rbind, lapply(r$InstanceGroups, function(s) {
        if (s$Name == "CORE" && s$Market == "ON_DEMAND") {
            data.table(type = s$InstanceType, running = s$RunningInstanceCount)
        }
    }))
    grp <- aws.list.groups(r)
    gtext <- if (length(grp) > 0) {
        sprintf("Number of Instance Groups: \%s\n\%s\n", length(grp), 
            paste(unlist(lapply(grp, function(s) {
                if (s$Market == "SPOT") {
                  sprintf("\tID:\%s, name: '\%s' state:\%s requested:\%s (at $\%s), running: \%s", 
                    s$Id, s$Name, s$Status$State, s$RequestedInstanceCount, 
                    s$BidPrice, s$RunningInstanceCount)
                }
                else {
                  sprintf("\tID:\%s, name: '\%s' state:\%s requested:\%s, running: \%s", 
                    s$Id, s$Name, s$Status$State, s$RequestedInstanceCount, 
                    s$RunningInstanceCount)
                }
            })), collapse = "\n"))
    }
    else ""
    awsconsole = sprintf("https://us-west-2.console.aws.amazon.com/elasticmapreduce/home?region=us-west-2#cluster-details:\%s", 
        r$Id)
    temp <- infuse("Cluster ID: {{clid}}\nThis Information As of: {{dd}}\nName: '{{name}}'\nState: {{state}}\nStarted At : {{started}}\nMessage: {{currently}}\nIP: {{dns}}\nSOCKS: ssh -ND 8157 hadoop@{{dns}} (and use FoxyProxy for Firefox or SwitchySharp for Chrome)\nRstudio: http://{{dns}}\nShiny: http://{{dns}}:3838\nJobTrakcer: http://{{dns}}:9026 (needs a socks)\nMaster Type: {{master}} (and is running: {{isrunning}})\nCore Nodes: {{nworker}} of  {{ workerstype }}\n{{gtext}}\n\n{{awsconsole}}\n", 
        list(clid = r$Id, dd = r$timeupdated, name = name, state = state, 
            started = started, currently = currently, dns = dns, 
            master = master["type"], isrunning = as.logical(master["running"]), 
            nworker = workers.core$running, workerstype = workers.core$type, 
            gtext = gtext, awsconsole = awsconsole))
    cat(temp)
  }
}
% Add one or more standard keywords, see file 'KEYWORDS' in the
% R documentation directory.
\keyword{ ~kwd1 }
\keyword{ ~kwd2 }% __ONLY ONE__ keyword per line
