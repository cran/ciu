# Not found out yet how to sort features according to CI (or CU)
# for all facets, now they are all sorted according to mean value of all CI
# (which might actually be a good choice).

# This is to get the CRAN check to go through. Thanks ChatGPT.
utils::globalVariables(c("feature.labels", "phi", "Positive.Phi", "feature.name"))

#' CIU feature importance/utility plot using ggplot.
#'
#' Create a barplot showing CI as the length of the bar and CU on color scale from
#' red to green, via yellow, for the given inputs and the given output.
#'
#' @inheritParams ciu.meta.explain
#' @inheritParams ciu.barplot
#' @param output.names Vector with names of outputs to include.
#' If NULL (default), then include all.
#' @param plot.mode "overlap" or "colour_cu". Default is "colour_cu".
#' @param ci.colours Colours to use for CI part in "overlap" mode. Three values
#' required: fill colour, border colour, alpha. Default is c("aquamarine", "aquamarine3", "0.3").
#' @param cu.colours Colours to use for CU part in "overlap" mode. Three values
#' required: fill colour, border colour, alpha. Default is c("darkgreen", "darkgreen", "0.8").
#' If it is set to NULL, then the same colour palette is used as for "colour_cu".
#' @param low.color Colour to use for CU=0
#' @param mid.color Colour to use for CU=Neutral.CU
#' @param high.color Colour to use for CU=1
#' @param scale.CI Scale x-axis according to maximal CI value.
#'
#' @return ggplot object.
#' @export
#' @author Kary Främling
#'
ciu.ggplot.col <- function(ciu, instance=NULL, ind.inputs=NULL, output.names=NULL,
                           in.min.max.limits=NULL,
                           n.samples=100, neutral.CU=0.5,
                           show.input.values=TRUE, concepts.to.explain=NULL,
                           target.concept=NULL, target.ciu=NULL,
                           ciu.meta = NULL,
                           plot.mode = "colour_cu", # overlap or colour_cu
                           ci.colours = c("aquamarine", "aquamarine3", "0.3"),
                           cu.colours = c("darkgreen", "darkgreen", "0.8"),
                           low.color="red", mid.color="yellow",
                           high.color="darkgreen",
                           use.influence=FALSE,
                           scale.CI=FALSE,
                           sort=NULL, decreasing=FALSE, # These are not used yet.
                           main=NULL) {
  # Allow using already existing result.
  if ( is.null(ciu.meta) ) {
    ciu.meta <- ciu.meta.explain(ciu, instance, ind.inputs=ind.inputs, in.min.max.limits=in.min.max.limits,
                                 n.samples=n.samples, concepts.to.explain=concepts.to.explain,
                                 target.concept=target.concept, target.ciu=target.ciu)
  }
  else {
    instance <- ciu.meta$instance
  }

  # Create data frame for ggplot plotting
  ind.inputs <- ciu.meta$ind.inputs
  inp.names <- ciu.meta$inp.names
  ci.cu <- data.frame()
  n.inps <- length(ciu.meta$ciuvals)
  for ( i in 1:n.inps ) {
    f.label <- inp.names[i]
    ciu.res <- ciu.meta$ciuvals[[i]]
    if ( show.input.values ) {
      # Didn't manage to get this done very elegantly...
      value <- instance[ind.inputs[i]]
      if ( is.data.frame(value) ) { # Crazy checks...
        if ( ncol(value) > 0 ) # For intermediate concepts that have no value.
          value <- value[[1]]
        else
          value <- ""
      }
      if ( is.numeric(value) )
        value <- format(value, digits=2)
      f.label <- paste(f.label, " (", value, ")", sep="")
      #f.label <- paste0(f.label, " (", as.character(instance[1,ind.inputs[i]]), ")")
    }

    # Some special treatment here for getting output names correct if result
    # variable is a factor, which leads to as many output classes as levels.
    if ( is.factor(ciu$data.out[,1]) && !is.null(ciu$output.names) ) {
      if ( length(levels(ciu$data.out[,1])) == length(ciu$output.names))
        rownames(ciu.res) <- ciu$output.names
    }

    # Only include the outputs that are indicated to be included,
    # otherwise include all
    if ( !is.null(output.names) ) {
      ciu.res <- ciu.res[row.names(ciu.res) %in% output.names,]
    }
    ci.cu <- rbind(ci.cu, data.frame(Label=rownames(ciu.res), Output.Value=ciu.res$outval,
                                     in.names=inp.names[i], CI=ciu.res$CI, CU=ciu.res$CU,
                                     Output=paste0(rownames(ciu.res), " (",
                                                   format(ciu.res$outval, digits=3), ")"),
                                     feature.labels=f.label)
    )
  }

  # "instance" has to be a data.frame so this can't be NULL.
  inst.name <- rownames(instance)

  # Sort facets according to output value. Sorting factor levels correctly does the job.
  ci.cu$Output <- factor(ci.cu$Output, unique(ci.cu$Output[order(ci.cu$Output.Value, decreasing = TRUE)]))

  # Check if main plot title has been given as parameter, otherwise use default one
  if ( is.null(main) ) {
    main <- paste("Studied instance (context):", inst.name)
    if  ( !is.null(target.concept) )
      main <- paste0(main, "\nTarget concept is \"", target.concept, "\"")
  }

  # Create the plot. Have to use some tricks here for avoiding warnings either
  # by devtools.check or during execution. Apparently devtools.check
  # doesn't understand attach() explicitly nor done by ggplot
  ci <- ci.cu$CI; cu <- ci.cu$CU

  # Include influence value too, in any case
  influence <- ci*(cu - neutral.CU)
  ci.cu$phi <- influence
  ci.cu$Positive.Phi <- influence >= 0

  # Influence plot separated because needs more than trivial manipulations.
  p <- ggplot(ci.cu)
  if ( use.influence ) {
    ymin <- min(influence); ymax <- max(influence)
    p <- p +
      geom_col(aes(reorder(feature.labels, phi), phi, fill=Positive.Phi)) +
      ylim(ymin, ymax) +
      labs(y = expression(phi)) +
      scale_fill_manual("legend", values = c("FALSE" = "firebrick", "TRUE" = "steelblue")) +
      theme(legend.position="none")
  }
  else {
    ymin <- 0
    ymax <- ifelse(scale.CI, max(ci), 1)
    p <- p + ylim(ymin, ymax)
    if ( plot.mode == "colour_cu" ) {
      p <- p +
        geom_col(aes(reorder(feature.labels, ci), ci, fill=cu)) +
        labs(y="CI", fill="CU") +
        scale_fill_gradient2(low=low.color, mid=mid.color, high=high.color, limits=c(0,1), midpoint=neutral.CU)
    }
    else {
      cu_scaled <- cu*ci
      p <- p +
        geom_bar(aes(x=reorder(feature.labels, ci), y=ci), stat="identity", position ="identity",
                 alpha=as.numeric(ci.colours[3]), fill=ci.colours[1], color=ci.colours[2])
      if ( is.null(cu.colours) ) {
        p <- p +
          geom_bar(aes(x=reorder(feature.labels, ci), y=cu_scaled, fill=cu), stat="identity", position="identity",
                   alpha=1.0, color='black') +
          scale_fill_gradient2(low=low.color, mid=mid.color, high=high.color, limits=c(0,1), midpoint=neutral.CU) +
          labs(y="CI and relative CU", fill="CU")
      }
      else {
        p <- p +
          geom_bar(aes(x=reorder(feature.labels, ci), y=cu_scaled), stat="identity", position="identity",
                   alpha=as.numeric(cu.colours[3]), fill=cu.colours[1], color=cu.colours[2]) +
          labs(y="CI and relative CU")
      }
      #   scale_colour_manual(values=c("lightblue4", "red")) +
      #   scale_fill_manual(values=c("lightblue", "pink")) +
      #   scale_alpha_manual(values=c(.3, .8))
    }
  }
  p <- p + coord_flip() +
    facet_wrap(~Output, labeller=label_both) + # Use scales="free_y" is different ordering for every facet
    ggtitle(main) +
    xlab("Feature")
  return(p)
}
