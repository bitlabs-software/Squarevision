"""
Executes some tests for the complete digitization of a chessboard.
"""

from Chess2FEN.lc2fen.predict_board import load_image
from Chess2FEN.lc2fen.test_predict_board import predict_board

from os.path import dirname, join

from tflite_runtime.interpreter import Interpreter

# PRE_INPUT example:
#   from keras.applications.mobilenet_v2 import preprocess_input as
#       prein_mobilenet
ACTIVATE_KERAS = True
MODEL_PATH_KERAS = join(dirname(__file__), "selected_models/Xception_last.h5")
IMG_SIZE_KERAS = 299


def test_predict_board(obtain_predictions, img_array, a1_pos="BL"):
    """Tests board prediction."""

    fen = predict_board(img_array, a1_pos,
                        obtain_predictions)

    return fen

def main_keras():
    """Executes Keras test board predictions."""
    # print("Keras predictions")
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

    test_predict_board(obtain_pieces_probs)
