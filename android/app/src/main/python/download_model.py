import sys
sys.path.append("./Chess2FEN")
import requests
import shutil
from os.path import dirname, join
import os

def download():
    url = "https://github.com/bitlabs-software/Squarevision/releases/download/v1.0.0/Xception.tflite"
    local_filename = join(os.environ["HOME"], "Xception.tflite")
    if not os.path.exists(local_filename):
        with requests.get(url, stream=True) as r:
            with open(local_filename, 'wb') as f:
                shutil.copyfileobj(r.raw, f)
        
