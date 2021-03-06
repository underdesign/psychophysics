concatenate <- function
###Concatenate multi-dimensional arrays along the given dimension, a
###generalization of cbind().  Arrays must have the same dimensions
###except gor the dimension along which the binding occurs. Attempts
###to preserve dimnames; if more than one argument provides names for
###a dimension, the earlier argument takes precedence.  Arrays may
###have different numbers of dimensions in which case they are taken
###to have length 1 in all training dimensions. Vectors without a dim
###attribute are taken to be column vectors.
(..., ###arguments to be bound
 along=N, ###the dimension along which arrays are to be
          ###bound. Defaults to the greatest number of dimensions
          ###among the arguments.
 match.names=FALSE, ###Attempt to arrange the data in a way that
                    ###matches dimnames between arguments (ala
                    ###smartbind.) When this is enabled, no slice
                    ###without a name will be bound to a slice with a
                    ###name. NB: this probably fails in new and
                    ###interesting ways if confronted with arrays that
                    ###have non=unique names.
 fill=match.names ###if set to TRUE, binding unequally sized or
                  ###mismatched arrays is permitted. NA will be used
                  ###to fill out the parts of the array not covered.
 ) {

  arg.list = list(...)

  #save original dimensions and number of dimensions. Undimensioned
  #vectors are assumed to be "column vectors"
  dims <- lapply(arg.list, function(x) if (is.null(dim(x))) length(x) else dim(x))
  N <- sapply(c(0, dims), length)
  N <- max(N, along)

  #capture the dimnames in a 2d array(arg no. dimension). We convert
  #NULLs to NAs because is.na works elementwise and is.null does not.
  apply.dimnames <- FALSE
  dno = array(list(NA), c(N, length(arg.list)))
  for (i in 1:length(arg.list)) {
    dn <- dimnames(arg.list[[i]])
    if (!is.null(dn)) {
      apply.dimnames <- TRUE
      dn[sapply(dn,is.null)] <- NA;
      dno[1:length(dn), i] <- dn;
    }
  }

  no.names.provided <- is.na(dno)
 
  #any unstated dimensions are assumed to be 1; one-pad the dimensions
  #here is the bug?
  arg.list <- mapply(function(arg, d) {
                       length(d) <- N;
                       d[is.na(d)] <- 1;
                       dim(arg) <- d;
                       arg
                     },
                     arg.list,
                     dims,
                     SIMPLIFY=FALSE)

  #useful to have a 2d array of the dimnames.
  dimarray <- do.call(rbind,lapply(arg.list, dim));
  #how to get a 2d array of the dimnames?
  dimnames.out <- vector("list", N);

  if (match.names) {
    ##determine the unique set of dimnames for each dimension; listed
    ##in order of appearance.
    dno[no.names.provided] <- list(character())

    ## i tried to do this with apply but ran into a trouble-with-small-numbers problem...
    # lapply(apply(dno[-along,,drop=FALSE], MARGIN=1, unlist), unique)
    for (i in (1:N)[-along]) {
      dimnames.out[[i]] <- unique(do.call(c, dno[i,]))
      dimnames.out[[i]] <- dimnames.out[[i]][dimnames.out[[i]] != ""]
    }

    ##Maximum number of unnamed elements in each dimension?
    nUnnamed <- array(
      mapply(function(dn, d) d - sum(dn != ""), t(dno), dimarray),
      dim(dno))
    maxUnnamed <- apply(nUnnamed, MARGIN=2, max)

    for (i in(1:N)[-along]) {
      length(dimnames.out[[i]]) <- length(dimnames.out[[i]]) + maxUnnamed[i]
      dimnames.out[[i]][is.na(dimnames.out[[i]])] <- list("")
    }
    
    ##Determine the permutation that brings each array into
    ##matched-names order, with the unnamed slices pushed after all
    ##the named slices.
    permutation <- array(list(NA), c(length(arg.list), N))
    for(argn in 1:length(arg.list)) {
      for (dimn in 1:N) {
        if (dimn == along) {
          permutation[[argn, dimn]] <- (1:dimarray[[argn, dimn]])
          next
        }
        if (is.na(dno[dimn, argn])) {
          iUnnnamed <- 1:dimarray[[argn, dimn]]
          iNamed <- numeric(0)
          names <- character(0)
        } else {
          iNamed <- which(dno[[dimn, argn]] != "")
          iUnnamed <- which(dno[[dimn, argn]] == "")
          names <- dno[[dimn, argn]][iNamed]
        }
        perm <- array(NA, length(dimnames.out[[dimn]]), dimnames=dimnames.out[dimn])
        perm[names] <- iNamed
        perm[seq(length(dimnames.out[[dimn]]) + 1 - maxUnnamed[dimn], len=length(iUnnamed))] <- iUnnamed
        if ((!fill) & any(is.na(perm))) {
          stop("there are unmatched names and fill set to FALSE")
        }
        permutation[[argn, dimn]] <- perm
      }
    }
    
    ##permute the arrays
    for (i in 1:length(arg.list)) {
      arg.list[[i]] = do.call("[", c(arg.list[i], permutation[i,]))
    }
  } else {
    ##if not attempting to match names, take the first names that win (in each row)
    ##the dimnames that wins is the first non-NA in every row.
    for (i in length(arg.list):1) {
      dimnames.out[!is.na(dno[,i])] <- dno[!is.na(dno[,i]),i]
    }
  }

  #Now deal with the dimnames in the concatenated dimension....
  if (apply.dimnames) {
    dno[no.names.provided] <- list(NA)
    nonames.args <- no.names.provided[along,]
    dno[along,nonames.args] <-
      lapply(arg.list[nonames.args],
             function(x)vector("character", dim(x)[along]))
    
    dimnames.out[[along]] <- do.call(c, dno[along,])
  }

  #the output dimension equals the max of the input dimensions and the concatenation...
  dimout <- do.call(pmax, c(lapply(arg.list, dim), list(rep(0,N))))

  #everything ought to have the same dimension otherwise, else we pad with NA
  if (!fill) {
    if (any(sapply(arg.list, function(x) any(dim(x)[-along] != dimout[-along])))) {
      stop("arguments should have consistent dimensions")
    }
  } else {
    arg.list <- lapply(arg.list, function(arg) {
      d <- dimout
      d[along] <- dim(arg)[along]
      extend(arg, d)
    })
  }
  #bring bound dimension to END
  permutation <-  c((1:N)[-along], along)
  arg.list <- lapply(arg.list, aperm, permutation)

  #straighten out other dimensions:
  arg.list <- lapply(arg.list, function(x)array(x, c(prod(dimout[-along]), dim(x)[N])))

  #desired output size:
  dimout[along] <- sum(sapply(arg.list, function(x)dim(x)[2]))
  
  #do cbind, reshape back and depermute
  bound <- array(do.call(cbind, arg.list), c(dimout[-along], dimout[along]))
  invperm <- permutation;
  invperm[permutation] <- (1:N)
  bound <- aperm(bound, invperm) #depermute

  #apply the dimnames.
  if(apply.dimnames) {
    dimnames(bound) <- dimnames.out
  }

  return(bound)
###The bound array.
}
