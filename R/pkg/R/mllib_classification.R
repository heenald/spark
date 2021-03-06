#
# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.
# The ASF licenses this file to You under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with
# the License.  You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

# mllib_regression.R: Provides methods for MLlib classification algorithms
#                     (except for tree-based algorithms) integration

#' S4 class that represents an LinearSVCModel
#'
#' @param jobj a Java object reference to the backing Scala LinearSVCModel
#' @export
#' @note LinearSVCModel since 2.2.0
setClass("LinearSVCModel", representation(jobj = "jobj"))

#' S4 class that represents an LogisticRegressionModel
#'
#' @param jobj a Java object reference to the backing Scala LogisticRegressionModel
#' @export
#' @note LogisticRegressionModel since 2.1.0
setClass("LogisticRegressionModel", representation(jobj = "jobj"))

#' S4 class that represents a MultilayerPerceptronClassificationModel
#'
#' @param jobj a Java object reference to the backing Scala MultilayerPerceptronClassifierWrapper
#' @export
#' @note MultilayerPerceptronClassificationModel since 2.1.0
setClass("MultilayerPerceptronClassificationModel", representation(jobj = "jobj"))

#' S4 class that represents a NaiveBayesModel
#'
#' @param jobj a Java object reference to the backing Scala NaiveBayesWrapper
#' @export
#' @note NaiveBayesModel since 2.0.0
setClass("NaiveBayesModel", representation(jobj = "jobj"))

#' linear SVM Model
#'
#' Fits an linear SVM model against a SparkDataFrame. It is a binary classifier, similar to svm in glmnet package
#' Users can print, make predictions on the produced model and save the model to the input path.
#'
#' @param data SparkDataFrame for training.
#' @param formula A symbolic description of the model to be fitted. Currently only a few formula
#'                operators are supported, including '~', '.', ':', '+', and '-'.
#' @param regParam The regularization parameter.
#' @param maxIter Maximum iteration number.
#' @param tol Convergence tolerance of iterations.
#' @param standardization Whether to standardize the training features before fitting the model. The coefficients
#'                        of models will be always returned on the original scale, so it will be transparent for
#'                        users. Note that with/without standardization, the models should be always converged
#'                        to the same solution when no regularization is applied.
#' @param threshold The threshold in binary classification, in range [0, 1].
#' @param weightCol The weight column name.
#' @param aggregationDepth The depth for treeAggregate (greater than or equal to 2). If the dimensions of features
#'                         or the number of partitions are large, this param could be adjusted to a larger size.
#'                         This is an expert parameter. Default value should be good for most cases.
#' @param ... additional arguments passed to the method.
#' @return \code{spark.svmLinear} returns a fitted linear SVM model.
#' @rdname spark.svmLinear
#' @aliases spark.svmLinear,SparkDataFrame,formula-method
#' @name spark.svmLinear
#' @export
#' @examples
#' \dontrun{
#' sparkR.session()
#' t <- as.data.frame(Titanic)
#' training <- createDataFrame(t)
#' model <- spark.svmLinear(training, Survived ~ ., regParam = 0.5)
#' summary <- summary(model)
#'
#' # fitted values on training data
#' fitted <- predict(model, training)
#'
#' # save fitted model to input path
#' path <- "path/to/model"
#' write.ml(model, path)
#'
#' # can also read back the saved model and predict
#' # Note that summary deos not work on loaded model
#' savedModel <- read.ml(path)
#' summary(savedModel)
#' }
#' @note spark.svmLinear since 2.2.0
setMethod("spark.svmLinear", signature(data = "SparkDataFrame", formula = "formula"),
          function(data, formula, regParam = 0.0, maxIter = 100, tol = 1E-6, standardization = TRUE,
                   threshold = 0.0, weightCol = NULL, aggregationDepth = 2) {
            formula <- paste(deparse(formula), collapse = "")

            if (!is.null(weightCol) && weightCol == "") {
              weightCol <- NULL
            } else if (!is.null(weightCol)) {
              weightCol <- as.character(weightCol)
            }

            jobj <- callJStatic("org.apache.spark.ml.r.LinearSVCWrapper", "fit",
                                data@sdf, formula, as.numeric(regParam), as.integer(maxIter),
                                as.numeric(tol), as.logical(standardization), as.numeric(threshold),
                                weightCol, as.integer(aggregationDepth))
            new("LinearSVCModel", jobj = jobj)
          })

#  Predicted values based on an LinearSVCModel model

#' @param newData a SparkDataFrame for testing.
#' @return \code{predict} returns the predicted values based on an LinearSVCModel.
#' @rdname spark.svmLinear
#' @aliases predict,LinearSVCModel,SparkDataFrame-method
#' @export
#' @note predict(LinearSVCModel) since 2.2.0
setMethod("predict", signature(object = "LinearSVCModel"),
          function(object, newData) {
            predict_internal(object, newData)
          })

#  Get the summary of an LinearSVCModel

#' @param object an LinearSVCModel fitted by \code{spark.svmLinear}.
#' @return \code{summary} returns summary information of the fitted model, which is a list.
#'         The list includes \code{coefficients} (coefficients of the fitted model),
#'         \code{intercept} (intercept of the fitted model), \code{numClasses} (number of classes),
#'         \code{numFeatures} (number of features).
#' @rdname spark.svmLinear
#' @aliases summary,LinearSVCModel-method
#' @export
#' @note summary(LinearSVCModel) since 2.2.0
setMethod("summary", signature(object = "LinearSVCModel"),
          function(object) {
            jobj <- object@jobj
            features <- callJMethod(jobj, "features")
            labels <- callJMethod(jobj, "labels")
            coefficients <- callJMethod(jobj, "coefficients")
            nCol <- length(coefficients) / length(features)
            coefficients <- matrix(unlist(coefficients), ncol = nCol)
            intercept <- callJMethod(jobj, "intercept")
            numClasses <- callJMethod(jobj, "numClasses")
            numFeatures <- callJMethod(jobj, "numFeatures")
            if (nCol == 1) {
              colnames(coefficients) <- c("Estimate")
            } else {
              colnames(coefficients) <- unlist(labels)
            }
            rownames(coefficients) <- unlist(features)
            list(coefficients = coefficients, intercept = intercept,
                 numClasses = numClasses, numFeatures = numFeatures)
          })

#  Save fitted LinearSVCModel to the input path

#' @param path The directory where the model is saved.
#' @param overwrite Overwrites or not if the output path already exists. Default is FALSE
#'                  which means throw exception if the output path exists.
#'
#' @rdname spark.svmLinear
#' @aliases write.ml,LinearSVCModel,character-method
#' @export
#' @note write.ml(LogisticRegression, character) since 2.2.0
setMethod("write.ml", signature(object = "LinearSVCModel", path = "character"),
function(object, path, overwrite = FALSE) {
    write_internal(object, path, overwrite)
})

#' Logistic Regression Model
#'
#' Fits an logistic regression model against a SparkDataFrame. It supports "binomial": Binary logistic regression
#' with pivoting; "multinomial": Multinomial logistic (softmax) regression without pivoting, similar to glmnet.
#' Users can print, make predictions on the produced model and save the model to the input path.
#'
#' @param data SparkDataFrame for training.
#' @param formula A symbolic description of the model to be fitted. Currently only a few formula
#'                operators are supported, including '~', '.', ':', '+', and '-'.
#' @param regParam the regularization parameter.
#' @param elasticNetParam the ElasticNet mixing parameter. For alpha = 0.0, the penalty is an L2 penalty.
#'                        For alpha = 1.0, it is an L1 penalty. For 0.0 < alpha < 1.0, the penalty is a combination
#'                        of L1 and L2. Default is 0.0 which is an L2 penalty.
#' @param maxIter maximum iteration number.
#' @param tol convergence tolerance of iterations.
#' @param family the name of family which is a description of the label distribution to be used in the model.
#'               Supported options:
#'                 \itemize{
#'                   \item{"auto": Automatically select the family based on the number of classes:
#'                           If number of classes == 1 || number of classes == 2, set to "binomial".
#'                           Else, set to "multinomial".}
#'                   \item{"binomial": Binary logistic regression with pivoting.}
#'                   \item{"multinomial": Multinomial logistic (softmax) regression without pivoting.}
#'                 }
#' @param standardization whether to standardize the training features before fitting the model. The coefficients
#'                        of models will be always returned on the original scale, so it will be transparent for
#'                        users. Note that with/without standardization, the models should be always converged
#'                        to the same solution when no regularization is applied. Default is TRUE, same as glmnet.
#' @param thresholds in binary classification, in range [0, 1]. If the estimated probability of class label 1
#'                  is > threshold, then predict 1, else 0. A high threshold encourages the model to predict 0
#'                  more often; a low threshold encourages the model to predict 1 more often. Note: Setting this with
#'                  threshold p is equivalent to setting thresholds c(1-p, p). In multiclass (or binary) classification to adjust the probability of
#'                  predicting each class. Array must have length equal to the number of classes, with values > 0,
#'                  excepting that at most one value may be 0. The class with largest value p/t is predicted, where p
#'                  is the original probability of that class and t is the class's threshold.
#' @param weightCol The weight column name.
#' @param aggregationDepth The depth for treeAggregate (greater than or equal to 2). If the dimensions of features
#'                         or the number of partitions are large, this param could be adjusted to a larger size.
#'                         This is an expert parameter. Default value should be good for most cases.
#' @param ... additional arguments passed to the method.
#' @return \code{spark.logit} returns a fitted logistic regression model.
#' @rdname spark.logit
#' @aliases spark.logit,SparkDataFrame,formula-method
#' @name spark.logit
#' @export
#' @examples
#' \dontrun{
#' sparkR.session()
#' # binary logistic regression
#' t <- as.data.frame(Titanic)
#' training <- createDataFrame(t)
#' model <- spark.logit(training, Survived ~ ., regParam = 0.5)
#' summary <- summary(model)
#'
#' # fitted values on training data
#' fitted <- predict(model, training)
#'
#' # save fitted model to input path
#' path <- "path/to/model"
#' write.ml(model, path)
#'
#' # can also read back the saved model and predict
#' # Note that summary deos not work on loaded model
#' savedModel <- read.ml(path)
#' summary(savedModel)
#'
#' # multinomial logistic regression
#'
#' model <- spark.logit(training, Class ~ ., regParam = 0.5)
#' summary <- summary(model)
#'
#' }
#' @note spark.logit since 2.1.0
setMethod("spark.logit", signature(data = "SparkDataFrame", formula = "formula"),
          function(data, formula, regParam = 0.0, elasticNetParam = 0.0, maxIter = 100,
                   tol = 1E-6, family = "auto", standardization = TRUE,
                   thresholds = 0.5, weightCol = NULL, aggregationDepth = 2) {
            formula <- paste(deparse(formula), collapse = "")

            if (!is.null(weightCol) && weightCol == "") {
              weightCol <- NULL
            } else if (!is.null(weightCol)) {
              weightCol <- as.character(weightCol)
            }

            jobj <- callJStatic("org.apache.spark.ml.r.LogisticRegressionWrapper", "fit",
                                data@sdf, formula, as.numeric(regParam),
                                as.numeric(elasticNetParam), as.integer(maxIter),
                                as.numeric(tol), as.character(family),
                                as.logical(standardization), as.array(thresholds),
                                weightCol, as.integer(aggregationDepth))
            new("LogisticRegressionModel", jobj = jobj)
          })

#  Get the summary of an LogisticRegressionModel

#' @param object an LogisticRegressionModel fitted by \code{spark.logit}.
#' @return \code{summary} returns summary information of the fitted model, which is a list.
#'         The list includes \code{coefficients} (coefficients matrix of the fitted model).
#' @rdname spark.logit
#' @aliases summary,LogisticRegressionModel-method
#' @export
#' @note summary(LogisticRegressionModel) since 2.1.0
setMethod("summary", signature(object = "LogisticRegressionModel"),
          function(object) {
            jobj <- object@jobj
            features <- callJMethod(jobj, "rFeatures")
            labels <- callJMethod(jobj, "labels")
            coefficients <- callJMethod(jobj, "rCoefficients")
            nCol <- length(coefficients) / length(features)
            coefficients <- matrix(unlist(coefficients), ncol = nCol)
            # If nCol == 1, means this is a binomial logistic regression model with pivoting.
            # Otherwise, it's a multinomial logistic regression model without pivoting.
            if (nCol == 1) {
              colnames(coefficients) <- c("Estimate")
            } else {
              colnames(coefficients) <- unlist(labels)
            }
            rownames(coefficients) <- unlist(features)

            list(coefficients = coefficients)
          })

#  Predicted values based on an LogisticRegressionModel model

#' @param newData a SparkDataFrame for testing.
#' @return \code{predict} returns the predicted values based on an LogisticRegressionModel.
#' @rdname spark.logit
#' @aliases predict,LogisticRegressionModel,SparkDataFrame-method
#' @export
#' @note predict(LogisticRegressionModel) since 2.1.0
setMethod("predict", signature(object = "LogisticRegressionModel"),
          function(object, newData) {
            predict_internal(object, newData)
          })

#  Save fitted LogisticRegressionModel to the input path

#' @param path The directory where the model is saved.
#' @param overwrite Overwrites or not if the output path already exists. Default is FALSE
#'                  which means throw exception if the output path exists.
#'
#' @rdname spark.logit
#' @aliases write.ml,LogisticRegressionModel,character-method
#' @export
#' @note write.ml(LogisticRegression, character) since 2.1.0
setMethod("write.ml", signature(object = "LogisticRegressionModel", path = "character"),
          function(object, path, overwrite = FALSE) {
            write_internal(object, path, overwrite)
          })

#' Multilayer Perceptron Classification Model
#'
#' \code{spark.mlp} fits a multi-layer perceptron neural network model against a SparkDataFrame.
#' Users can call \code{summary} to print a summary of the fitted model, \code{predict} to make
#' predictions on new data, and \code{write.ml}/\code{read.ml} to save/load fitted models.
#' Only categorical data is supported.
#' For more details, see
#' \href{http://spark.apache.org/docs/latest/ml-classification-regression.html}{
#'   Multilayer Perceptron}
#'
#' @param data a \code{SparkDataFrame} of observations and labels for model fitting.
#' @param formula a symbolic description of the model to be fitted. Currently only a few formula
#'                operators are supported, including '~', '.', ':', '+', and '-'.
#' @param blockSize blockSize parameter.
#' @param layers integer vector containing the number of nodes for each layer.
#' @param solver solver parameter, supported options: "gd" (minibatch gradient descent) or "l-bfgs".
#' @param maxIter maximum iteration number.
#' @param tol convergence tolerance of iterations.
#' @param stepSize stepSize parameter.
#' @param seed seed parameter for weights initialization.
#' @param initialWeights initialWeights parameter for weights initialization, it should be a
#' numeric vector.
#' @param ... additional arguments passed to the method.
#' @return \code{spark.mlp} returns a fitted Multilayer Perceptron Classification Model.
#' @rdname spark.mlp
#' @aliases spark.mlp,SparkDataFrame,formula-method
#' @name spark.mlp
#' @seealso \link{read.ml}
#' @export
#' @examples
#' \dontrun{
#' df <- read.df("data/mllib/sample_multiclass_classification_data.txt", source = "libsvm")
#'
#' # fit a Multilayer Perceptron Classification Model
#' model <- spark.mlp(df, label ~ features, blockSize = 128, layers = c(4, 3), solver = "l-bfgs",
#'                    maxIter = 100, tol = 0.5, stepSize = 1, seed = 1,
#'                    initialWeights = c(0, 0, 0, 0, 0, 5, 5, 5, 5, 5, 9, 9, 9, 9, 9))
#'
#' # get the summary of the model
#' summary(model)
#'
#' # make predictions
#' predictions <- predict(model, df)
#'
#' # save and load the model
#' path <- "path/to/model"
#' write.ml(model, path)
#' savedModel <- read.ml(path)
#' summary(savedModel)
#' }
#' @note spark.mlp since 2.1.0
setMethod("spark.mlp", signature(data = "SparkDataFrame", formula = "formula"),
          function(data, formula, layers, blockSize = 128, solver = "l-bfgs", maxIter = 100,
                   tol = 1E-6, stepSize = 0.03, seed = NULL, initialWeights = NULL) {
            formula <- paste(deparse(formula), collapse = "")
            if (is.null(layers)) {
              stop ("layers must be a integer vector with length > 1.")
            }
            layers <- as.integer(na.omit(layers))
            if (length(layers) <= 1) {
              stop ("layers must be a integer vector with length > 1.")
            }
            if (!is.null(seed)) {
              seed <- as.character(as.integer(seed))
            }
            if (!is.null(initialWeights)) {
              initialWeights <- as.array(as.numeric(na.omit(initialWeights)))
            }
            jobj <- callJStatic("org.apache.spark.ml.r.MultilayerPerceptronClassifierWrapper",
                                "fit", data@sdf, formula, as.integer(blockSize), as.array(layers),
                                as.character(solver), as.integer(maxIter), as.numeric(tol),
                                as.numeric(stepSize), seed, initialWeights)
            new("MultilayerPerceptronClassificationModel", jobj = jobj)
          })

#  Returns the summary of a Multilayer Perceptron Classification Model produced by \code{spark.mlp}

#' @param object a Multilayer Perceptron Classification Model fitted by \code{spark.mlp}
#' @return \code{summary} returns summary information of the fitted model, which is a list.
#'         The list includes \code{numOfInputs} (number of inputs), \code{numOfOutputs}
#'         (number of outputs), \code{layers} (array of layer sizes including input
#'         and output layers), and \code{weights} (the weights of layers).
#'         For \code{weights}, it is a numeric vector with length equal to the expected
#'         given the architecture (i.e., for 8-10-2 network, 112 connection weights).
#' @rdname spark.mlp
#' @export
#' @aliases summary,MultilayerPerceptronClassificationModel-method
#' @note summary(MultilayerPerceptronClassificationModel) since 2.1.0
setMethod("summary", signature(object = "MultilayerPerceptronClassificationModel"),
          function(object) {
            jobj <- object@jobj
            layers <- unlist(callJMethod(jobj, "layers"))
            numOfInputs <- head(layers, n = 1)
            numOfOutputs <- tail(layers, n = 1)
            weights <- callJMethod(jobj, "weights")
            list(numOfInputs = numOfInputs, numOfOutputs = numOfOutputs,
                 layers = layers, weights = weights)
          })

#  Makes predictions from a model produced by spark.mlp().

#' @param newData a SparkDataFrame for testing.
#' @return \code{predict} returns a SparkDataFrame containing predicted labeled in a column named
#' "prediction".
#' @rdname spark.mlp
#' @aliases predict,MultilayerPerceptronClassificationModel-method
#' @export
#' @note predict(MultilayerPerceptronClassificationModel) since 2.1.0
setMethod("predict", signature(object = "MultilayerPerceptronClassificationModel"),
          function(object, newData) {
            predict_internal(object, newData)
          })

#  Saves the Multilayer Perceptron Classification Model to the input path.

#' @param path the directory where the model is saved.
#' @param overwrite overwrites or not if the output path already exists. Default is FALSE
#'                  which means throw exception if the output path exists.
#'
#' @rdname spark.mlp
#' @aliases write.ml,MultilayerPerceptronClassificationModel,character-method
#' @export
#' @seealso \link{write.ml}
#' @note write.ml(MultilayerPerceptronClassificationModel, character) since 2.1.0
setMethod("write.ml", signature(object = "MultilayerPerceptronClassificationModel",
          path = "character"),
          function(object, path, overwrite = FALSE) {
            write_internal(object, path, overwrite)
          })

#' Naive Bayes Models
#'
#' \code{spark.naiveBayes} fits a Bernoulli naive Bayes model against a SparkDataFrame.
#' Users can call \code{summary} to print a summary of the fitted model, \code{predict} to make
#' predictions on new data, and \code{write.ml}/\code{read.ml} to save/load fitted models.
#' Only categorical data is supported.
#'
#' @param data a \code{SparkDataFrame} of observations and labels for model fitting.
#' @param formula a symbolic description of the model to be fitted. Currently only a few formula
#'               operators are supported, including '~', '.', ':', '+', and '-'.
#' @param smoothing smoothing parameter.
#' @param ... additional argument(s) passed to the method. Currently only \code{smoothing}.
#' @return \code{spark.naiveBayes} returns a fitted naive Bayes model.
#' @rdname spark.naiveBayes
#' @aliases spark.naiveBayes,SparkDataFrame,formula-method
#' @name spark.naiveBayes
#' @seealso e1071: \url{https://cran.r-project.org/package=e1071}
#' @export
#' @examples
#' \dontrun{
#' data <- as.data.frame(UCBAdmissions)
#' df <- createDataFrame(data)
#'
#' # fit a Bernoulli naive Bayes model
#' model <- spark.naiveBayes(df, Admit ~ Gender + Dept, smoothing = 0)
#'
#' # get the summary of the model
#' summary(model)
#'
#' # make predictions
#' predictions <- predict(model, df)
#'
#' # save and load the model
#' path <- "path/to/model"
#' write.ml(model, path)
#' savedModel <- read.ml(path)
#' summary(savedModel)
#' }
#' @note spark.naiveBayes since 2.0.0
setMethod("spark.naiveBayes", signature(data = "SparkDataFrame", formula = "formula"),
          function(data, formula, smoothing = 1.0) {
            formula <- paste(deparse(formula), collapse = "")
            jobj <- callJStatic("org.apache.spark.ml.r.NaiveBayesWrapper", "fit",
            formula, data@sdf, smoothing)
            new("NaiveBayesModel", jobj = jobj)
          })

#  Returns the summary of a naive Bayes model produced by \code{spark.naiveBayes}

#' @param object a naive Bayes model fitted by \code{spark.naiveBayes}.
#' @return \code{summary} returns summary information of the fitted model, which is a list.
#'         The list includes \code{apriori} (the label distribution) and
#'         \code{tables} (conditional probabilities given the target label).
#' @rdname spark.naiveBayes
#' @export
#' @note summary(NaiveBayesModel) since 2.0.0
setMethod("summary", signature(object = "NaiveBayesModel"),
          function(object) {
            jobj <- object@jobj
            features <- callJMethod(jobj, "features")
            labels <- callJMethod(jobj, "labels")
            apriori <- callJMethod(jobj, "apriori")
            apriori <- t(as.matrix(unlist(apriori)))
            colnames(apriori) <- unlist(labels)
            tables <- callJMethod(jobj, "tables")
            tables <- matrix(tables, nrow = length(labels))
            rownames(tables) <- unlist(labels)
            colnames(tables) <- unlist(features)
            list(apriori = apriori, tables = tables)
          })

#  Makes predictions from a naive Bayes model or a model produced by spark.naiveBayes(),
#  similarly to R package e1071's predict.

#' @param newData a SparkDataFrame for testing.
#' @return \code{predict} returns a SparkDataFrame containing predicted labeled in a column named
#' "prediction".
#' @rdname spark.naiveBayes
#' @export
#' @note predict(NaiveBayesModel) since 2.0.0
setMethod("predict", signature(object = "NaiveBayesModel"),
          function(object, newData) {
            predict_internal(object, newData)
          })

#  Saves the Bernoulli naive Bayes model to the input path.

#' @param path the directory where the model is saved.
#' @param overwrite overwrites or not if the output path already exists. Default is FALSE
#'                  which means throw exception if the output path exists.
#'
#' @rdname spark.naiveBayes
#' @export
#' @seealso \link{write.ml}
#' @note write.ml(NaiveBayesModel, character) since 2.0.0
setMethod("write.ml", signature(object = "NaiveBayesModel", path = "character"),
          function(object, path, overwrite = FALSE) {
            write_internal(object, path, overwrite)
          })
