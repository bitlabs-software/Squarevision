"""
Board prediction testing.
"""
import time

from Chess2FEN.lc2fen.fen import list_to_board, board_to_fen, compare_fen
from Chess2FEN.lc2fen.infer_pieces import infer_chess_pieces
from Chess2FEN.lc2fen.predict_board import detect_input_board, obtain_individual_pieces


def predict_board(board_array, a1_pos, obtain_pieces_probs):
    """
    Predict the fen notation of a chessboard. Prints the elapsed times.

    The obtain_predictions argument allows us to predict using different
    methods (such as Keras, ONNX or TensorRT models) that may need
    additional context.

    :param board_array: Path to the board to detect. Must have rw permission.
        For example: '../predictions/board.jpg'.
    :param a1_pos: Position of the a1 square. Must be one of the
        following: "BL", "BR", "TL", "TR".
    :param obtain_pieces_probs: Function which receives a list with the
        path to each piece image in FEN notation order and returns the
        corresponding probabilities of each piece belonging to each
        class as another list.
    :return: Predicted fen string representing the chessboard.
    """
    total_time = 0

    start = time.perf_counter()
    detect_input_board(board_array)
    elapsed_time = time.perf_counter() - start
    total_time += elapsed_time
    # print(f"Elapsed time detecting the input board: {elapsed_time}")

    start = time.perf_counter()
    pieces = obtain_individual_pieces(board_array)
    elapsed_time = time.perf_counter() - start
    total_time += elapsed_time
    # print(f"Elapsed time obtaining the individual pieces: {elapsed_time}")

    start = time.perf_counter()
    pieces_probs = obtain_pieces_probs(pieces)
    elapsed_time = time.perf_counter() - start
    total_time += elapsed_time
    # print(f"Elapsed time predicting probabilities: {elapsed_time}")

    start = time.perf_counter()
    predictions = infer_chess_pieces(pieces_probs, a1_pos)
    elapsed_time = time.perf_counter() - start
    total_time += elapsed_time
    # print(f"Elapsed time inferring chess pieces: {elapsed_time}")

    start = time.perf_counter()
    board = list_to_board(predictions)
    fen = board_to_fen(board)
    elapsed_time = time.perf_counter() - start
    total_time += elapsed_time
    # print(f"Elapsed time converting to fen notation: {elapsed_time}")

    # print(f"Elapsed total time: {total_time}")

    return fen


def print_fen_comparison(board_name, fen, correct_fen):
    """
    Compares the predicted fen with the correct fen and pretty prints
    the result.

    :param board_name: Name of the board. For example: 'test1.jpg'
    :param fen: Predicted fen string.
    :param correct_fen: Correct fen string.
    """
    n_dif = compare_fen(fen, correct_fen)
    # print(board_name[:-4] + ' - Err:' + str(n_dif)
        # + " Acc:{:.2f}% FEN:".format(1 - (n_dif / 64)) + fen + '\n')
