/// Ambiguous words never select a category without qualifying context.
class CategorySemantics {
  static const senses = <String, List<String>>{
    'tay': ['education', 'housewares', 'beautify'],
    'muc': ['market', 'eating', 'education', 'beautify'],
    'chuot': ['pet', 'personal_belongings'],
    'dau': ['market', 'vehicle_maintenance', 'personal_belongings', 'housewares'],
    'duong': ['market', 'move'],
    'kinh': ['personal_belongings', 'repair_and_decorate_the_house', 'vehicle_maintenance'],
    'banh': ['eating', 'vehicle_maintenance', 'housewares'],
    'sac': ['personal_belongings', 'move'],
    'pin': ['personal_belongings', 'housewares', 'vehicle_maintenance'],
    'son': ['beautify', 'repair_and_decorate_the_house', 'vehicle_maintenance'],
    'keo': ['education', 'repair_and_decorate_the_house', 'housewares', 'eating'],
    'kem': ['eating', 'beautify', 'personal_belongings'],
    'nuoc': ['eating', 'water_money', 'housewares', 'beautify'],
    'ca': ['market', 'eating', 'pet'],
    'ga': ['market', 'eating', 'pet'],
    'sua': ['eating', 'market', 'personal_belongings', 'pet'],
    'bot': ['market', 'housewares', 'beautify', 'physical_examination'],
    'hoa': ['gifts_donations', 'repair_and_decorate_the_house', 'market'],
    'bong': ['sport', 'housewares', 'fun_play'],
    'the': ['telephone_fee', 'other_costs', 'fun_play', 'gifts_donations'],
    've': ['move', 'fun_play', 'sport'],
    'day': ['personal_belongings', 'housewares', 'pet', 'sport', 'education'],
    'vong': ['personal_belongings', 'pet', 'sport'],
    'ong': ['housewares', 'repair_and_decorate_the_house', 'physical_examination', 'personal_belongings'],
    'binh': ['housewares', 'gas_money', 'vehicle_maintenance'],
    'quat': ['housewares', 'personal_belongings', 'vehicle_maintenance'],
    'loc': ['housewares', 'vehicle_maintenance', 'personal_belongings'],
    'den': ['housewares', 'vehicle_maintenance', 'repair_and_decorate_the_house'],
    'hat': ['market', 'eating', 'pet', 'repair_and_decorate_the_house'],
    'vai': ['market', 'personal_belongings', 'housewares'],
    'ban': ['housewares', 'personal_belongings', 'education'],
  };

  // Explicit replies to a pending ambiguous word only. Never search globally.
  static const replies = <String, Map<String, String>>{
    'tay': {'but chi':'education', 'cuc tay':'education', 'gom':'education', 'tay chi':'education', 'quan ao':'housewares', 'bon cau':'housewares', 'lau nha':'housewares', 'tay rua':'housewares', 'toc':'beautify', 'tay toc':'beautify', 'trang':'beautify', 'tay trang':'beautify', 'long':'beautify'},
    'muc': {
      'de viet': 'education', 'viet': 'education', 'but bi': 'education',
      'but may': 'education', 'trong but bi': 'education',
      'dung trong but bi': 'education', 'de in': 'education', 'may in': 'education',
      'writing ink': 'education', 'printer ink': 'education',
      'tuoi': 'market', 'loai tuoi': 'market', 'song': 'market',
      'ong tuoi': 'market', 'muc ong tuoi': 'market', 'ong song': 'market',
      'de nau': 'market', 'mua ve nau': 'market', 'chua che bien': 'market',
      'raw squid': 'market', 'fresh squid': 'market',
      'nuong': 'eating', 'chien': 'eating', 'xao': 'eating', 'hap': 'eating',
      'an lien': 'eating', 'da nau': 'eating', 'de an ngay': 'eating',
      'cooked squid': 'eating', 'de xam': 'beautify', 'phun xam': 'beautify',
    },
    'chuot': {'may tinh':'personal_belongings', 'khong day':'personal_belongings',
      'bluetooth':'personal_belongings', 'de dung may tinh':'personal_belongings',
      'computer mouse':'personal_belongings', 'hamster':'pet','chuot lang':'pet',
      'nuoi canh':'pet', 'de nuoi':'pet'},
    'dau': {'de nau an':'market','dau an':'market','de goi dau':'personal_belongings',
      'goi dau':'personal_belongings','duong toc':'personal_belongings',
      'thay nhot xe':'vehicle_maintenance','nhot xe':'vehicle_maintenance',
      'dong co':'vehicle_maintenance','lau san':'housewares'},
    'duong': {'de nau an':'market','duong cat':'market','duong phen':'market',
      'cau duong':'move','phi duong bo':'move'},
    'kinh': {'de deo':'personal_belongings','kinh can':'personal_belongings',
      'cua so':'repair_and_decorate_the_house','cua nha':'repair_and_decorate_the_house',
      'kinh o to':'vehicle_maintenance'},
    'banh': {'de an':'eating','banh xe':'vehicle_maintenance',
      'xe may':'vehicle_maintenance','o to':'vehicle_maintenance','ghe':'housewares'},
    'sac': {'dien thoai':'personal_belongings','laptop':'personal_belongings',
      'xe dien':'move','sac xe':'move'},
    'pin': {'dien thoai':'personal_belongings','laptop':'personal_belongings',
      'dieu khien tivi':'housewares','dong ho treo tuong':'housewares',
      'thay cho xe dien':'vehicle_maintenance'},
    'son': {'son moi':'beautify','mong tay':'beautify','mong chan':'beautify',
      'tuong nha':'repair_and_decorate_the_house','son nha':'repair_and_decorate_the_house',
      'son xe':'vehicle_maintenance'},
    'keo': {'dan giay':'education','hoc sinh':'education',
      'dan gach':'repair_and_decorate_the_house','chong tham':'repair_and_decorate_the_house',
      'dan do gia dung':'housewares','keo an':'eating'},
    'kem': {'de an':'eating','kem que':'eating','duong da':'beautify',
      'chong nang':'beautify','danh rang':'personal_belongings'},
    'nuoc': {'de uong': 'eating', 'nuoc uong': 'eating', 'sinh hoat': 'water_money', 'hoa don nuoc': 'water_money', 'lau san': 'housewares', 'rua chen': 'housewares', 'tay trang': 'beautify'},
    'ca': {'tuoi': 'market', 'song de nau': 'market', 'de nau': 'market', 'da nau': 'eating', 'chien': 'eating', 'nuong': 'eating', 'nuoi canh': 'pet', 'ca canh': 'pet'},
    'ga': {'song de nau': 'market', 'thit song': 'market', 'de nau': 'market', 'ga ran': 'eating', 'da nau': 'eating', 'luoc chin': 'eating', 'nuoi canh': 'pet'},
    'sua': {'de uong': 'eating', 'de lam banh': 'market', 'nguyen lieu': 'market', 'sua tam': 'personal_belongings', 'tam': 'personal_belongings', 'cho cho': 'pet', 'cho meo': 'pet'},
    'bot': {'lam banh': 'market', 'nau an': 'market', 'giat do': 'housewares', 'bot giat': 'housewares', 'trang diem': 'beautify', 'bot thuoc': 'physical_examination'},
    'hoa': {'de tang': 'gifts_donations', 'tang sinh nhat': 'gifts_donations', 'trang tri nha': 'repair_and_decorate_the_house', 'de nau an': 'market', 'an duoc': 'market'},
    'bong': {'the thao': 'sport', 'bong da': 'sport', 'bong ro': 'sport', 'bong den': 'housewares', 'den': 'housewares', 'bong bay': 'fun_play'},
    'the': {'dien thoai': 'telephone_fee', 'the cao': 'telephone_fee', 'phi the ngan hang': 'other_costs', 'game': 'fun_play', 'qua tang': 'gifts_donations'},
    've': {'xe': 'move', 'tau': 'move', 'may bay': 'move', 'xem phim': 'fun_play', 'tham quan': 'fun_play', 'ho boi': 'sport', 'tap gym': 'sport'},
    'day': {'sac dien thoai': 'personal_belongings', 'dien trong nha': 'housewares', 'dat cho': 'pet', 'dan cho': 'pet', 'nhay the duc': 'sport', 'khang luc': 'sport', 'dan guitar': 'education'},
    'vong': {'trang suc': 'personal_belongings', 'deo tay': 'personal_belongings', 'co cho': 'pet', 'co meo': 'pet', 'tap the duc': 'sport', 'lac eo': 'sport'},
    'ong': {'hut nuoc': 'housewares', 'nuoc sua nha': 'repair_and_decorate_the_house', 'y te': 'physical_examination', 'kinh may anh': 'personal_belongings'},
    'binh': {'nuoc': 'housewares', 'giu nhiet': 'housewares', 'gas nau an': 'gas_money', 'ac quy xe': 'vehicle_maintenance'},
    'quat': {'gia dinh': 'housewares', 'dung trong nha': 'housewares', 'tan nhiet may tinh': 'personal_belongings', 'lam mat xe': 'vehicle_maintenance'},
    'loc': {'nuoc gia dinh': 'housewares', 'khong khi': 'housewares', 'gio xe': 'vehicle_maintenance', 'nhot xe': 'vehicle_maintenance', 'kinh may anh': 'personal_belongings'},
    'den': {'de ban': 'housewares', 'trong nha': 'housewares', 'xe': 'vehicle_maintenance', 'trang tri nha': 'repair_and_decorate_the_house'},
    'hat': {'nguyen lieu': 'market', 'an lien': 'eating', 'cho cho': 'pet', 'cho meo': 'pet', 'giong trong hoa': 'repair_and_decorate_the_house'},
    'vai': {'qua vai': 'market', 'trai vai': 'market', 'may ao': 'personal_belongings', 'may quan': 'personal_belongings', 'may rem': 'housewares', 'may ga giuong': 'housewares'},
    'ban': {'ban ghe': 'housewares', 'ban an': 'housewares', 'phim may tinh': 'personal_belongings', 'bang hoc': 'education'},
  };

  static const spellings = <String, List<String>>{
    'tay': ['tẩy'],
    'muc': ['mực'],
    'chuot': ['chuột'],
    'dau': ['dầu'],
    'duong': ['đường'],
    'kinh': ['kính'],
    'banh': ['bánh'],
    'sac': ['sạc'],
    'pin': ['pin'],
    'son': ['son', 'sơn'],
    'keo': ['keo', 'kẹo'],
    'kem': ['kem'],
    'nuoc': ['nước'],
    'ca': ['cá'],
    'ga': ['gà'],
    'sua': ['sữa'],
    'bot': ['bột'],
    'hoa': ['hoa'],
    'bong': ['bóng'],
    'the': ['thẻ'],
    've': ['vé'],
    'day': ['dây'],
    'vong': ['vòng'],
    'ong': ['ống'],
    'binh': ['bình'],
    'quat': ['quạt'],
    'loc': ['lọc'],
    'den': ['đèn'],
    'hat': ['hạt'],
    'vai': ['vải'],
    'ban': ['bàn'],
  };

  static bool acceptsSpelling(String term, String? original) {
    if (original == null) return true;
    final word = original.toLowerCase();
    return word == term || (spellings[term]?.contains(word) ?? false);
  }

  /// Short category answers only narrow the choices already offered.
  /// Inputs and labels are accent-folded; item descriptions are not searched here.
  static List<String> categoryReplyChoices(
      String folded, Map<String, String> labels, Iterable<String> pending) {
    final answer = folded.trim()
        .replaceFirst(RegExp(r'^(?:chon|muc|danh muc|la|choose|category|it is)\s+'), '')
        .replaceAll(RegExp(r'[.!?]+$'), '').trim();
    if (answer.isEmpty) return const [];
    final result = <String>[];
    for (final key in pending) {
      final label = labels[key] ?? '';
      final exact = answer == key || answer == label;
      final partial = answer.split(RegExp(r'\s+')).length >= 2 &&
          (' $label ').contains(' $answer ');
      final household = answer == 'do dung' &&
          (key == 'personal_belongings' || key == 'housewares');
      if (exact || partial || household) result.add(key);
    }
    return result;
  }

  static String? resolveReply(String? term, String folded) {
    if (term == null) return null;
    final reply = folded.replaceAll(RegExp(r'^[\s,.;:!?]+|[\s,.;:!?]+$'), '')
        .replaceFirst(RegExp(r'^(?:la|loai|it is)\s+'), '');
    return replies[term]?[reply];
  }
}
