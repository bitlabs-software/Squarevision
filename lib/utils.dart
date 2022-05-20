/// Check the formatting of a FEN String is correct
/// Returns a Map with keys valid, error_number, and error
Map? validate_fen(String? fen) {
  const errors = {
    0: 'No errors.',
    1: 'FEN string must contain six space-delimited fields.',
    2: '6th field (move number) must be a positive integer.',
    3: '5th field (half move counter) must be a non-negative integer.',
    4: '4th field (en-passant square) is invalid.',
    5: '3rd field (castling availability) is invalid.',
    6: '2nd field (side to move) is invalid.',
    7: '1st field (piece positions) does not contain 8 \'/\'-delimited rows.',
    8: '1st field (piece positions) is invalid [consecutive numbers].',
    9: '1st field (piece positions) is invalid [invalid piece].',
    10: '1st field (piece positions) is invalid [row too large].',
  };

  /* 1st criterion: 6 space-seperated fields? */
  List tokens = fen!.split(" ");

  /* 2nd criterion: move number field is a integer value > 0? */
  var temp = int.tryParse(tokens[5]);
  if (temp != null) {
    if (temp <= 0) {
      return {'valid': false, 'error_number': 2, 'error': errors[2]};
    }
  } else {
    return {'valid': false, 'error_number': 2, 'error': errors[2]};
  }

  /* 3rd criterion: half move counter is an integer >= 0? */
  temp = int.tryParse(tokens[4]);
  if (temp != null) {
    if (temp < 0) {
      return {'valid': false, 'error_number': 3, 'error': errors[3]};
    }
  } else {
    return {'valid': false, 'error_number': 3, 'error': errors[3]};
  }

  /* 4th criterion: 4th field is a valid e.p.-string? */
  final check4 = RegExp(r'^(-|[abcdefgh][36])$');
  if (check4.firstMatch(tokens[3]) == null) {
    return {'valid': false, 'error_number': 4, 'error': errors[4]};
  }

  /* 5th criterion: 3th field is a valid castle-string? */
  final check5 = RegExp(r'^(KQ?k?q?|Qk?q?|kq?|q|-)$');
  if (check5.firstMatch(tokens[2]) == null) {
    return {'valid': false, 'error_number': 5, 'error': errors[5]};
  }

  /* 6th criterion: 2nd field is "w" (white) or "b" (black)? */
  var check6 = RegExp(r'^([wb])$');
  if (check6.firstMatch(tokens[1]) == null) {
    return {'valid': false, 'error_number': 6, 'error': errors[6]};
  }

  /* 7th criterion: 1st field contains 8 rows? */
  List rows = tokens[0].split('/');
  if (rows.length != 8) {
    return {'valid': false, 'error_number': 7, 'error': errors[7]};
  }

  /* 8th criterion: every row is valid? */
  for (var i = 0; i < rows.length; i++) {
    /* check for right sum of fields AND not two numbers in succession */
    var sum_fields = 0;
    var previous_was_number = false;

    for (var k = 0; k < rows[i].length; k++) {
      final temp2 = int.tryParse(rows[i][k]);
      if (temp2 != null) {
        if (previous_was_number) {
          return {'valid': false, 'error_number': 8, 'error': errors[8]};
        }
        sum_fields += temp2;
        previous_was_number = true;
      } else {
        final checkOM = RegExp(r'^[prnbqkPRNBQK]$');
        if (checkOM.firstMatch(rows[i][k]) == null) {
          return {'valid': false, 'error_number': 9, 'error': errors[9]};
        }
        sum_fields += 1;
        previous_was_number = false;
      }
    }

    if (sum_fields != 8) {
      return {'valid': false, 'error_number': 10, 'error': errors[10]};
    }
  }

  /* everything's okay! */
  return {'valid': true, 'error_number': 0, 'error': errors[0]};
}
