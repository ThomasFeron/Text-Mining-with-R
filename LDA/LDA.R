library(dplyr)
library(easyPubMed)
library(ggplot2)
library(quanteda)
library(stringr)
library(tidytext)
library(topicmodels)
library(XML)
library(tictoc)

tic("full script")
##### PART 1: text mining


# 52349 documents via importation du fichier xml.

papers <- xmlParse(file = "~/Documents/Projet_Text_mininig/pubmed18n0924.xml")

# Preprocessing des abstracts
#---------------------------

xmltop = xmlRoot(papers) # top node of "papers" xml structure
Article_Num <- xmlSize(xmltop) # number of nodes (Articles) "in papers"
# xmlSApply(xmltop[[1]], xmlName) # shows names of child nodes

ID <- vector()
Abstract <- vector()
Title <- vector()
Date <- vector()
Author_lastname <- vector()
Author_forename <- vector()
Author <- vector()

for (i in 1:Article_Num) {
  ID[i] <- xmlValue(xmltop[[i]][["MedlineCitation"]][["PMID"]])
  Abstract[i] <- xmlValue(xmltop[[i]][["MedlineCitation"]][["Article"]][["Abstract"]])
  Title[i] <- xmlValue(xmltop[[i]][["MedlineCitation"]][["Article"]][["ArticleTitle"]])
  Date[i] <- xmlValue(xmltop[[i]][["MedlineCitation"]][["Article"]][["ArticleDate"]])
  Author_lastname[i] <- xmlValue(xmltop[[i]][["MedlineCitation"]][["Article"]][["AuthorList"]][["Author"]][["LastName"]])
  Author_forename[i] <- xmlValue(xmltop[[i]][["MedlineCitation"]][["Article"]][["AuthorList"]][["Author"]][["ForeName"]])
  Author[i] <- paste(Author_lastname[i],Author_forename[i])
}

# create dataframe
df <- data.frame(ID, Abstract, Title, Date, Author)
# Remove Na's and too long or too short Abstracts.
df <- df[complete.cases(df[ , 2]),] 
df <- df[nchar(as.character(df[ , 2]))<3000 & nchar(as.character(df[ , 2]))>100,] 

############### PART 2: text mining

Abstract <- as.character(df$Abstract)
NbrDoc<-10000
raw <- Abstract[1:NbrDoc]

# Tokenize
tokens <- tokens(raw, what = "word", 
                 remove_numbers = TRUE, remove_punct = TRUE,
                 remove_symbols = TRUE, remove_hyphens = TRUE)


# minimize capital letters
tokens <- tokens_tolower(tokens)

# stopwords
stop<-stopwords()
new_stopwords<-append(stop,c("fig.","eq.","abstracttext"))
tokens <- tokens_select(tokens, new_stopwords, selection = "remove")

# Create our first bag-of-words model.
tokens.dfm <- dfm(tokens, tolower = FALSE)

# Transform to a matrix and inspect.
tokens.matrix <- as.matrix(tokens.dfm)
dim(tokens.matrix)


#--------------------------------------------------------------------------

k=20
ap_lda <- LDA(tokens.matrix, k, control = list(seed = 1234))

ap_topics <- tidy(ap_lda, matrix = "beta")

ap_top_terms <- ap_topics %>%
  group_by(topic) %>%
  top_n(200, beta) %>%
  ungroup() %>%
  arrange(topic, -beta)

ap_top_terms %>%
  mutate(term = reorder(term, beta)) %>%
  ggplot(aes(term, beta, fill = factor(topic))) +
  geom_col(show.legend = FALSE) +
  facet_wrap(~ topic, scales = "free") +
  coord_flip()

ap_documents <- tidy(ap_lda, matrix = "gamma")



toc()

beta1 <-0

positive_querry='cancer'
negative_querry='breast'

ind_pos <- which(ap_top_terms$term==positive_querry)  
topic_int_pos <- ap_top_terms$topic[ind_pos]  

if (length(topic_int_pos)<1) {
  print("Your positive querry isn't significant in any of our topics, try an other research")
}

ind_neg <- which(ap_top_terms$term==negative_querry)
topic_int_neg <- ap_top_terms$topic[ind_neg]

if (length(topic_int_neg)<1) {
  print("Your negative querry isn't significant in any of our topics, try an other research or continue" )
}

topic_int_tot <- setdiff(topic_int_pos,topic_int_neg)

if (length(topic_int_tot)<1) {
  print("Sorry, we will not take into account the negative request")
  topic_int_tot <- topic_int_pos
 }

ind3 <- which(ap_documents$topic %in% c(topic_int_tot))

df <- ap_documents[c(ind3),]
df$beta1=0
for (i in 1:nrow(df)) {
  for (j in 1:length(topic_int_tot)) {
    if (df$topic[i]==topic_int_tot[j]) {
      df$beta1[i]=ap_top_terms$beta[ind_pos[j]]
    }
  }
}

df$pond1=0
df$pond1=df$gamma+df$beta1

result <- df[order(-df$pond1),]
head(result)

top_text <- select(head(result,200),"document")
top_text
top_text_number <- 0
right_text <- NA
wrong_text <- NA
tot_text <- NA
perfect_match <- 0

for (j in 1:200) {
  top_text_number[j] <- as.numeric(as.character(gsub("text",'',top_text[j,1])))
}

for (k in top_text_number){
  right_text[match(k,top_text_number)]<-grepl(positive_querry, Abstract[k])
  wrong_text[match(k,top_text_number)]<-grepl(negative_querry, Abstract[k])
}

tot_text <- setdiff(top_text_number[right_text],top_text_number[wrong_text])

length(top_text_number[right_text])
length(top_text_number[wrong_text])
length(tot_text)
print(head(tot_text))
print(Abstract[head(tot_text,10)])
