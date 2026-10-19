/// Common action words. These are NOT counted as category vocabulary.
/// Input passed to these helpers must be lower-case and accent-folded by parser.
class TransactionActionKeywords {
  static const purchase = <String>[
    'paid for the', 'paid the', 'settled the', 'payment for the',
    'bought the', 'purchased the', 'ordered the', 'spent on the',
    'settled', 'payment for',
    'chi tien mua', 'tra tien mua', 'thanh toan tien mua',
    'chi tien cho', 'chi tien', 'chi cho', 'tra tien',
    'vua mua', 'da mua', 'moi mua', 'dat mua', 'mua them', 'mua',
    'thanh toan', 'bought', 'purchased', 'paid for', 'spent on',
    'ordered', 'buy', 'paid', 'spent',
  ];

  static final RegExp purchasePattern = RegExp(
    '(?<![a-z0-9])(?:${purchase.map(RegExp.escape).join('|')})(?![a-z0-9])',
  );
  /// Receive verbs must not be confused with the noun "nhẫn" after folding.
  static final RegExp incomeActionPattern = RegExp(
    r'\bnhan(?: duoc)?(?: tien)?(?= (?:hoa hong|loi tuc|co tuc|thu nhap|thuong|phu cap|loi nhuan|chia loi nhuan|cong|ban|luong|lai|hoan|tro cap|qua|tien)\b)',
  );
  /// A subject before an action is conversational context, not an item.
  /// Anchored so "mua tỏi" still keeps the garlic noun.
  static final RegExp narrativePrefixPattern = RegExp(
    r'^(?:(?:hom nay|hom qua|sang nay|chieu nay|toi nay)\s+)?'
    r'(?:toi|minh|em|anh|chi|chung toi|chung minh|i|we)\s+'
    r'(?:(?:vua|da|moi|just|already)\s+)*'
    r'(?=(?:mua|dat mua|chi|tra|thanh toan|nhan|an|uong|in|di|print|printed|buy|bought|paid|purchased|ordered|received|ate|drank)\b)',
  );
  /// Neutral transaction words never determine a category by themselves.
  /// Longer phrases such as "tiền điện" still supply their own evidence.
  static final RegExp neutralPattern = RegExp(
    r'\b(?:chi phi|khoan chi|khoan tien|so tien|tien|het|cost|expense|amount)\b',
  );
  /// Leading shopping context can be removed from a generated note.
  /// Explicit user notes are handled separately by the parser.
  static final RegExp shoppingPrefixPattern = RegExp(
    r'^\s*(?:di\s+)?(?:cho|sieu thi)\s+mua\s+',
  );
  static bool hasPurchase(String folded) => purchasePattern.hasMatch(folded);

  static final RegExp unrealized = RegExp(
    r'\b(khong|chua|dinh|du dinh|se|sap|muon)\s+(?:dat\s+)?(?:mua|chi|tra|thanh toan|nhan|dong)\b|'
    r'\b(not bought|did not buy|have not bought|planning to buy|plan to buy|will buy|want to buy)\b',
  );

  /// Only used at the beginning of a note. Never delete words inside an item.
  static final RegExp leading = RegExp(
    '^\\s*(?:${purchase.map(RegExp.escape).join('|')}|'
    'toi|minh|em|anh|ban|di|da|vua|moi|co|an|uong|dung|chi tieu|chi|tra|'
    'nhan|dong|gui|i|we|just|had|ate|drank|received|a|the|have|already|xong|for|of)\\s+',
  );
}
