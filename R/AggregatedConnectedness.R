
#' @title Aggregated Connectedness Measures
#' @description This function results in aggregated connectedness measures.
#' @param dca Dynamic connectedness object
#' @param groups List of at least two group vectors
#' @param start Start index
#' @param end End index
#' @return Get connectedness measures
#' @examples
#' \donttest{
#' #Replication of Gabauer and Gupta (2018)
#' data("gg2018")
#' dca = ConnectednessApproach(gg2018, 
#'                             nlag=1, 
#'                             nfore=10, 
#'                             window.size=200,
#'                             model="TVP-VAR",
#'                             connectedness="Time",
#'                             VAR_config=list(TVPVAR=list(kappa1=0.99, kappa2=0.99, 
#'                             prior="BayesPrior")))
#' ac = AggregatedConnectedness(dca, groups=list("US"=c(1,2,3,4), "JP"=c(5,6,7,8)))
#' }
#' @references Chatziantoniou, I., Gabauer, D., & Stenfor, A. (2021). Independent Policy, Dependent Outcomes: A Game of Cross-Country Dominoes across European Yield Curves (No. 2021-06). University of Portsmouth, Portsmouth Business School, Economics and Finance Subject Group.
#' @author David Gabauer
#' @export
AggregatedConnectedness = function(dca, groups, start=NULL, end=NULL) {
  corrected = dca$config$corrected
  message("Aggregated connectedness measures are introduced accoring to:\n Chatziantoniou, I., Gabauer, D., & Stenfor, A. (2021). Independent Policy, Dependent Outcomes: A Game of Cross-Country Dominoes across European Yield Curves (No. 2021-06). University of Portsmouth, Portsmouth Business School, Economics and Finance Subject Group.")
  if (is.null(start)) {
    start = 1
  }
  if (is.null(end)) {
    end = dim(dca$CT)[3]
  }
  NAMES = dimnames(dca$NET)[[2]]
  k = length(NAMES)
  m = length(groups)
  CT = dca$CT
  t = dim(CT)[3]
  weights = NULL
  for (i in 1:m) {
    weights[i] = length(groups[i][[1]])
  }
  
  if (is.null(names(groups))) {
    NAMES_group = paste0("GROUP", 1:m)
  } else {
    NAMES_group = names(groups)
  }
  date = as.character(as.Date(dimnames(CT)[[3]]))
  
  if (length(groups) <= 1) {
    stop("groups need to consist of at least 2 vectors")
  }
  
  if (dca$config$approach == "Joint") {
    stop(paste("Aggregated connectedness measures are not implemented for", 
               dca$config$approach, "connectedness"))
  } else if (dca$config$approach == "Frequency") {
    mn = dim(CT)[4]
    TABLE = list()
    horizons = dimnames(CT)[[4]]
    TCI_ = TCI = array(NA, c(t,mn), dimnames=list(date,horizons))
    FROM = TO = NET = array(NA, c(t,m,mn), dimnames=list(date, NAMES_group,horizons))
    CT_ = NPDC = INFLUENCE = array(NA, c(m,m,t,mn), dimnames=list(NAMES_group, NAMES_group, date,horizons))
    for (jl in 1:mn) {
      for (il in 1:t) {
        ct0 = ct = CT[,,il,jl]
        for (i in 1:m) {
          for (j in 1:m) {
            if (i==j) {
              ct0[groups[i][[1]], groups[j][[1]]] = 0
            }
          }
        }
        ct1 = array(0, c(m, m), dimnames=list(NAMES_group, NAMES_group))
        for (i in 1:m) {
          for (j in 1:m) {
            ct1[i,j] = sum(ct0[groups[i][[1]], groups[j][[1]]])# / length(groups[j][[1]])
          }
        }
        for (i in 1:m) {
          ct1[i,i] = sum(ct[i,])-sum(ct1[i,])
        }
        CT_[,,il,jl] = ct1
        dca_ = ConnectednessTable(ct1)
        if (corrected) {
          TCI[il,jl] = dca_$cTCI
          TCI_[il,jl] = sum(dca_$TO * (k-weights)/(k-1))
        } else {
          TCI[il,jl] = dca_$TCI
          TCI_[il,jl] = sum(dca_$TO * (k-weights)/k)
        }
        TO[il,,jl] = dca_$TO
        FROM[il,,jl] = dca_$FROM
        NET[il,,jl] = dca_$NET
        NPDC[,,il,jl] = dca_$NPDC
      }
      TABLE[[jl]] = ConnectednessTable(CT_[,,,jl])$TABLE
    }
    names(TABLE) = horizons
  } else {
    TCI_ = TCI = array(NA, c(t,1), dimnames=list(date, "TCI"))
    FROM = TO = NET = array(NA, c(t,m), dimnames=list(date, NAMES_group))
    CT_ = PDC = INFLUENCE = array(NA, c(m,m,t), dimnames=list(NAMES_group, NAMES_group, date))
    for (il in 1:t) {
      ct0 = ct = CT[,,il]
      for (i in 1:m) {
        for (j in 1:m) {
          if (i==j) {
            ct0[groups[i][[1]], groups[j][[1]]] = 0
          }
        }
      }
      ct1 = array(0, c(m, m), dimnames=list(NAMES_group, NAMES_group))
      for (i in 1:m) {
        for (j in 1:m) {
          ct1[i,j] = sum(ct0[groups[i][[1]], groups[j][[1]]]) / length(groups[j][[1]])
        }
      }
      for (i in 1:m) {
        ct1[i,i] = 1-sum(ct1[i,])
      }
      CT_[,,il] = ct1
      dca_ = ConnectednessTable(ct1)
      if (corrected) {
        TCI[il, ] = dca_$cTCI
        TCI_[il,] = sum(dca_$TO * (k-weights)/(k-1))
      } else {
        TCI[il, ] = dca_$TCI
        TCI_[il,] = sum(dca_$TO * (k-weights)/k)
      }
      TO[il,] = dca_$TO
      FROM[il,] = dca_$FROM
      NET[il,] = dca_$NET
      NPDC[,,il] = dca_$NPDC
    }
    TABLE = ConnectednessTable(CT_)$TABLE
  }
  config = list(approach="Aggregated")
  return = list(TABLE=TABLE, TCI_ext=TCI_, TCI=TCI, 
                TO=TO, FROM=FROM, NPT=NULL, NET=NET, 
                NPDC=NPDC, INFLUENCE=NULL, PCI=NULL, config=config)
}
