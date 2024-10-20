from fastapi import FastAPI

import spacy

nlp = spacy.load("pl_core_news_lg")
app = FastAPI()


@app.get("/nlp/{word}")
def extract_entities(word: str):
    doc = nlp(word)
    res = {}
    for token in doc:
        res[token.text] = {"type": token.pos_, "morph": token.morph.to_dict()}
    return res
