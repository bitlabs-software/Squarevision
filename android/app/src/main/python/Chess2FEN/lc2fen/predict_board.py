"""
Predicts board configurations from images.
"""
import glob
import os
import re
import shutil
import time

import numpy as np

from Chess2FEN.lc2fen.detectboard.detect_board import detect, compute_corners
from Chess2FEN.lc2fen.fen import list_to_board, board_to_fen
from Chess2FEN.lc2fen.infer_pieces import infer_chess_pieces
from Chess2FEN.lc2fen.split_board import split_square_board_image

from os.path import dirname, join
import cv2

def load_image(img_path, img_size):
    """
    Loads an image from its path. Intended to use with piece images.

    :param img_path: Image path.
    :param img_size: Size of the input image. For example: 224
    :param preprocess_func: Preprocessing fuction to apply to the input
        image.
    :return: The loaded image.
    """
    img_tensor = cv2.imread(img_path)
    img_tensor = cv2.cvtColor(img_tensor, cv2.COLOR_BGR2RGB)
    img_tensor = cv2.resize(img_tensor, (img_size, img_size))
    img_tensor = np.expand_dims(img_tensor, axis=0)
    img_tensor = np.interp(img_tensor, (img_tensor.min(), img_tensor.max()), (-1, +1))
    img_tensor = np.float32(img_tensor)
    return img_tensor


def detect_input_board(board_array, board_corners=None):
    """
    Detects the input board and stores the result as 'tmp/board_name in
    the folder containing the board. If the folder tmp exists, deletes
    its contents. If not, creates the tmp folder.

    :param board_array: Path to the board to detect. Must have rw
        permission.
        For example: '../predictions/board.jpg'.
    :param board_corners: A list of the coordinates of the four board
        corners. If it is not None, first check if the board is in the
        position given by these corners. If not, runs the full
        detection.
    :return: A list of the new coordinates of the four board corners
        detected.
    """
    
    input_array = board_array
    tmp_dir = join(os.environ["HOME"], "board", "tmp")
    os.makedirs(join(os.environ["HOME"], 'board'), exist_ok=True)
    os.makedirs(tmp_dir, exist_ok=True)
    os.makedirs(join(tmp_dir, "pieces"), exist_ok=True)
    image_object = detect(input_array, join(tmp_dir, "board.jpg"),
                          board_corners)
    board_corners, _ = compute_corners(image_object)
    return board_corners



def obtain_individual_pieces(board_array):
    """
    Obtain the individual pieces of a board.

    :param board_path: Path to the board to detect. Must have rw
        permission. The detected board should be in a tmp folder as done
        by detect_input_board.
        For example: '../predictions/board.jpg'.
    :return: List with the path to each piece image.
    """
    tmp_dir = join(os.environ["HOME"], os.path.join("board", "tmp"))
    pieces_dir = os.path.join(tmp_dir, "pieces")
    split_square_board_image(os.path.join(tmp_dir, "board.jpg"), "", pieces_dir)
    return sorted(glob.glob(pieces_dir + "/*.jpg"))


def predict_board_keras(model_path, img_size, path, a1_pos, is_dir):
    """
    Predict the fen notation of a chessboard using Keras for inference.

    :param model_path: Path to the Keras model.
    :param img_size: Model image input size.
    :param pre_input: Model preprocess input function.
    :param path: Path to the board or directory to detect. Must have rw
        permission.
        For example: '../predictions/board.jpg' or '../predictions/'.
    :param a1_pos: Position of the a1 square. Must be one of the
        following: "BL", "BR", "TL", "TR".
    :param is_dir: Whether path is a directory to monitor or a single
        board.
    :return: Predicted FEN string representing the chessboard.
    """
    model = Interpreter(model_path=model_path)
    model.allocate_tensors()

    # Get input and output tensors.
    input_details = model.get_input_details()
    output_details = model.get_output_details()

    # Test the model on random input data.
    input_shape = input_details[0]['shape']

    def obtain_pieces_probs(pieces):
        predictions = []
        for piece in pieces:
            piece_img = load_image(piece, img_size)

            model.set_tensor(input_details[0]['index'], piece_img)

            model.invoke()

            # The function `get_tensor()` returns a copy of the tensor data.
            # Use `tensor()` in order to get a pointer to the tensor.
            pred = model.get_tensor(output_details[0]['index'])[0]

            predictions.append(pred)
        return predictions

    if is_dir:
        return continuous_predictions(path, a1_pos, obtain_pieces_probs)
    else:
        return predict_board(path, a1_pos, obtain_pieces_probs)


def predict_board(board_array, a1_pos, obtain_pieces_probs, board_corners=None,
                  previous_fen=None):
    """
    Predict the fen notation of a chessboard.

    The obtain_predictions argument allows us to predict using different
    methods (such as Keras, ONNX or TensorRT models) that may need
    additional context.

    :param board_array: Path to the board to detect. Must have rw
        permission.
        For example: '../predictions/board.jpg'.
    :param a1_pos: Position of the a1 square. Must be one of the
        following: "BL", "BR", "TL", "TR".
    :param obtain_pieces_probs: Function which receives a list with the
        path to each piece image in FEN notation order and returns the
        corresponding probabilities of each piece belonging to each
        class as another list.
    :param board_corners: A list of the coordinates of the four board
        corners. If it is not None, first check if the board is in the
        position given by these corners. If not, runs the full
        detection.
    :param previous_fen: The FEN string representing the previous move
        of the same board. If it is not None, improves piece inference.
    :return: A pair formed by the predicted FEN string representing the
        chessboard and the coordinates of the corners of the chessboard
        in the input image.
    """
    board_corners = detect_input_board(board_array, board_corners)
    pieces = obtain_individual_pieces(board_array)
    pieces_probs = obtain_pieces_probs(pieces)
    predictions = infer_chess_pieces(pieces_probs, a1_pos, previous_fen)

    board = list_to_board(predictions)
    fen = board_to_fen(board)

    return fen, board_corners


def continuous_predictions(path, a1_pos, obtain_pieces_probs):
    """
    Continuously monitors path and predicts any new jpg images added to
    this directory, printing its FEN string. This function doesn't
    return.

    :param path: Path to the board or directory to detect. Must have rw
        permission.
        For example: '../predictions/board.jpg' or '../predictions/'.
    :param a1_pos: Position of the a1 square. Must be one of the
        following: "BL", "BR", "TL", "TR".
    :param obtain_pieces_probs: Function which receives a list with the
        path to each piece image in FEN notation order and returns the
        corresponding probabilities of each piece belonging to each
        class as another list.
    """
    if not os.path.isdir(path):
        raise ValueError("The path parameter must be a directory")

    def natural_key(text):
        return [int(c) if c.isdigit() else c for c in re.split(r'(\d+)', text)]

    # print("Done loading. Monitoring " + path)
    board_corners = None
    fen = None
    processed_board = False
    while True:
        for board_array in sorted(glob.glob(path + '*.jpg'), key=natural_key):
            fen, board_corners = predict_board(board_array, a1_pos,
                                               obtain_pieces_probs,
                                               board_corners,
                                               fen)
            # print(fen)
            processed_board = True
            os.remove(board_array)

        if not processed_board:
            time.sleep(0.1)
