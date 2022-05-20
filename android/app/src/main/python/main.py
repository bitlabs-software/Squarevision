from pyexpat import model
import sys
sys.path.append("./Chess2FEN")
from Chess2FEN.test_lc2fen import test_predict_board
from Chess2FEN.lc2fen.predict_board import load_image

import cv2

from os.path import dirname, join
import os

from tflite_runtime.interpreter import Interpreter

MODEL_PATH_KERAS = join(os.environ["HOME"], "Xception.tflite")
IMG_SIZE_KERAS = 299

"""Executes Keras test board predictions."""
# # print("Keras predictions")
# Load the TFLite model and allocate tensors.
model = Interpreter(model_path=MODEL_PATH_KERAS)
model.allocate_tensors()

# Get input and output tensors.
input_details = model.get_input_details()
output_details = model.get_output_details()

# Test the model on random input data.
input_shape = input_details[0]['shape']

def obtain_pieces_probs(pieces):
    predictions = []
    for piece in pieces:
        piece_img = load_image(piece, IMG_SIZE_KERAS)
        
        model.set_tensor(input_details[0]['index'], piece_img)

        model.invoke()

        # The function `get_tensor()` returns a copy of the tensor data.
        # Use `tensor()` in order to get a pointer to the tensor.
        pred = model.get_tensor(output_details[0]['index'])[0]
  
        predictions.append(pred)
    return predictions

def predict(filepath, a1_pos):
    img_array = cv2.imread(filepath)

    fen = test_predict_board(obtain_pieces_probs, img_array, a1_pos)

    return fen