import 'package:personal_financial_management/core/constants/list.dart';

class CategoryMatch {
  final int type;
  final String key;
  final double confidence;

  const CategoryMatch(this.type, this.key, this.confidence);
}

/// Nhận diện danh mục từ cách nói tự nhiên của người dùng.
///
/// Từ khóa được chuẩn hóa bỏ dấu trước khi so khớp, vì vậy các câu như
/// "đi ăn phở", "di an pho" và "pho ga" đều có thể về danh mục ăn uống.
class CategoryMatcher {
  static const Map<String, List<String>> _aliases = {
    'market': [
      'đi chợ', 'chợ', 'siêu thị', 'mua rau', 'mua thịt', 'mua cá',
      'tạp hóa', 'bách hóa', 'groceries', 'supermarket', 'market',
    ],

    'eating': [
      'ăn', 'ăn sáng', 'ăn trưa', 'ăn tối', 'ăn khuya', 'bữa sáng',
      'bữa trưa', 'bữa tối', 'cơm', 'cơm tấm', 'cơm phần', 'cơm gà',
      'cơm chiên', 'phở', 'phở bò', 'phở gà', 'bún', 'bún bò', 'bún chả',
      'bún thịt nướng', 'mì', 'mì gói', 'mì cay', 'hủ tiếu', 'cháo',
      'bánh mì', 'bánh bao', 'xôi', 'gỏi', 'lẩu', 'nướng', 'đồ ăn',
      'thức ăn', 'thực phẩm', 'mua đồ ăn', 'đặt đồ ăn', 'giao đồ ăn', 'ship đồ ăn',
      'đi ăn', 'quán ăn', 'nhà hàng', 'canteen', 'food', 'eat', 'lunch',
      'dinner', 'breakfast', 'brunch', 'pho', 'noodle', 'restaurant',
      'food delivery', 'grabfood', 'shopeefood', 'baemin', 'doordash',
      'nước dừa', 'dừa tươi', 'nước mía', 'nước cam', 'nước chanh',
      'nước sâm', 'nước rau má', 'sữa đậu nành', 'sữa tươi',
      'đồ uống', 'nước uống', 'nước lọc', 'nước suối', 'trà', 'trà sữa',
      'cà phê', 'cafe', 'coffee', 'sinh tố', 'nước ép', 'bia', 'rượu',
      'nước ngọt', 'pepsi', 'coca', 'milk tea', 'drink', 'beverage',
    ],

    // Đi lại và phương tiện.
    'move': [
      'taxi', 'grab', 'grabcar', 'grabbike', 'be', 'gojek', 'uber',
      'xe ôm', 'xe om', 'xe máy', 'xe bus', 'xe buýt', 'bus', 'metro',
      'tàu điện', 'tàu hỏa', 'máy bay', 'vé máy bay', 'vé xe', 'vé tàu',
      'đi lại', 'di chuyển', 'giao thông', 'đưa đón', 'đi làm', 'đi học',
      'đổ xăng', 'tiền xăng', 'xăng xe', 'nhiên liệu', 'sạc xe', 'bãi xe',
      'giữ xe', 'gửi xe', 'phí cầu đường', 'trạm thu phí', 'parking',
      'transport', 'transportation', 'fuel', 'gasoline', 'bus', 'train',
      'flight', 'taxi fare',
    ],

    // Nhà ở và các hóa đơn định kỳ.
    'rent_house': [
      'tiền nhà', 'thuê nhà', 'tiền thuê', 'phòng trọ', 'tiền trọ',
      'nhà trọ', 'chung cư', 'tiền chung cư', 'tiền phòng', 'thuê phòng',
      'đặt cọc nhà', 'house rent', 'rent', 'apartment', 'rental',
    ],
    'water_money': [
      'tiền nước', 'hóa đơn nước', 'hoá đơn nước', 'nước sinh hoạt',
      'water bill', 'water fee', 'water',
    ],
    'electricity_bill': [
      'tiền điện', 'hóa đơn điện', 'hoá đơn điện', 'điện sinh hoạt',
      'electricity', 'electric bill', 'power bill',
    ],
    'gas_money': [
      'tiền gas', 'bình gas', 'gas nhà bếp', 'gas bếp', 'thay bình gas',
      'gas bill', 'cooking gas', 'gas',
    ],
    'telephone_fee': [
      'tiền điện thoại', 'cước điện thoại', 'nạp điện thoại', 'nạp sim',
      'sim 4g', 'data điện thoại', 'gói cước', 'điện thoại tháng',
      'phone bill', 'mobile bill', 'mobile data', 'top up phone',
    ],
    'internet_money': [
      'tiền mạng', 'tiền internet', 'cước mạng', 'wifi', 'lắp mạng',
      'internet', 'internet bill', 'network fee', 'broadband',
    ],
    'tv_money': [
      'truyền hình', 'cước truyền hình', 'truyền hình cáp', 'k+','fpt play',
      'net tv', 'tv bill', 'cable tv',
    ],

    // Sửa chữa và đồ dùng gia đình.
    'repair_and_decorate_the_house': [
      'sửa nhà', 'sửa chữa nhà', 'sơn nhà', 'trang trí nhà', 'nội thất',
      'sửa điện nước', 'thợ sửa nhà', 'lắp đặt nhà', 'decor nhà',
      'repair house', 'home repair', 'home decoration', 'renovation',
    ],
    'housewares': [
      'đồ gia dụng', 'đồ dùng nhà', 'dụng cụ nhà bếp', 'nồi', 'chảo',
      'bát', 'chén', 'đũa', 'ly', 'cốc', 'bình nước', 'quạt', 'bếp',
      'máy hút bụi', 'chăn', 'ga giường', 'gối', 'mền', 'khăn',
      'houseware', 'home appliance', 'kitchenware', 'furniture',
    ],
    'vehicle_maintenance': [
      'bảo dưỡng xe', 'sửa xe', 'thay nhớt', 'thay dầu', 'vá xe',
      'thay lốp', 'thay vỏ', 'sửa xe máy', 'rửa xe', 'phụ tùng xe',
      'vehicle maintenance', 'car repair', 'motorbike repair', 'service car',
    ],

    // Sức khỏe, bảo hiểm và gia đình.
    'physical_examination': [
      'khám bệnh', 'khám sức khỏe', 'bệnh viện', 'bác sĩ', 'thuốc',
      'mua thuốc', 'nhà thuốc', 'chữa bệnh', 'nha khoa', 'niềng răng',
      'xét nghiệm', 'phẫu thuật', 'viện phí', 'doctor', 'hospital',
      'medicine', 'pharmacy', 'dental', 'health check',
    ],
    'insurance': [
      'bảo hiểm', 'bảo hiểm y tế', 'bảo hiểm xe', 'bảo hiểm nhân thọ',
      'bảo hiểm xã hội', 'insurance', 'health insurance', 'life insurance',
    ],
    'pet': [
      'thú cưng', 'vật nuôi', 'động vật cảnh',
      'chăm sóc thú cưng', 'nuôi thú cưng',
      'pet', 'pets', 'pet animal', 'companion animal',

      'chó', 'cún', 'chó con', 'cún con', 'chó cảnh',
      'chó mèo', 'dog', 'dogs', 'puppy', 'puppies',
      'chó ta', 'chó cỏ', 'chó Phú Quốc',
      'chó Bắc Hà', 'chó H’Mông cộc', 'chó Mông cộc',
      'chó poodle', 'toy poodle', 'miniature poodle',
      'chó phốc', 'phốc sóc', 'pomeranian',
      'chó chihuahua', 'chó corgi', 'chó pug',
      'chó husky', 'siberian husky',
      'chó alaska', 'alaskan malamute',
      'chó samoyed', 'chó golden', 'golden retriever',
      'chó labrador', 'labrador retriever',
      'chó shiba', 'shiba inu', 'chó akita', 'akita inu',
      'chó beagle', 'chó border collie',
      'chó becgie', 'german shepherd',
      'chó rottweiler', 'chó doberman',
      'chó bulldog', 'french bulldog', 'english bulldog',
      'chó dachshund', 'chó lạp xưởng',
      'chó dalmatian', 'chó đốm',
      'chó maltese', 'chó shih tzu',
      'chó bichon', 'bichon frise',
      'chó Yorkshire', 'Yorkshire terrier',
      'chó schnauzer', 'chó chow chow',
      'chó Bắc Kinh', 'pekingese',
      'chó basset hound', 'chó cocker spaniel',

      'mèo', 'mèo con', 'mèo cảnh',
      'cat', 'cats', 'kitten', 'kittens',
      'mèo ta', 'mèo mướp', 'mèo tam thể',
      'mèo mun', 'mèo vàng', 'mèo tuxedo',
      'mèo Anh lông ngắn', 'mèo Anh lông dài',
      'british shorthair', 'british longhair',
      'mèo Mỹ lông ngắn', 'american shorthair',
      'mèo Ba Tư', 'persian cat',
      'mèo Xiêm', 'siamese cat',
      'mèo ragdoll', 'ragdoll cat',
      'mèo maine coon', 'maine coon cat',
      'mèo bengal', 'bengal cat',
      'mèo sphynx', 'mèo không lông',
      'mèo scottish fold', 'mèo tai cụp',
      'mèo scottish straight', 'mèo tai thẳng',
      'mèo munchkin', 'mèo chân ngắn',
      'mèo Nga xanh', 'russian blue cat',
      'mèo Siberia', 'siberian cat',
      'mèo rừng Na Uy', 'norwegian forest cat',
      'mèo birman', 'mèo burmese',
      'mèo abyssinian', 'mèo somali',
      'mèo devon rex', 'mèo cornish rex',
      'mèo exotic', 'exotic shorthair',

      'thỏ cảnh', 'thỏ kiểng', 'thỏ cưng',
      'thỏ lùn', 'thỏ tai cụp', 'thỏ sư tử',
      'thỏ holland lop', 'thỏ mini lop',
      'thỏ netherland dwarf', 'thỏ angora',
      'pet rabbit', 'bunny', 'holland lop',
      'mini lop rabbit', 'lionhead rabbit',
      'netherland dwarf rabbit', 'angora rabbit',

      'chuột hamster', 'hamster', 'hamster con',
      'hamster bear', 'hamster syrian',
      'hamster winter white', 'hamster robo',
      'hamster roborovski', 'hamster campbell',
      'syrian hamster', 'dwarf hamster',
      'roborovski hamster', 'chinese hamster',
      'bọ ú', 'chuột lang', 'guinea pig',
      'guinea pigs', 'skinny pig',
      'chuột chinchilla', 'chinchilla',
      'chuột gerbil', 'gerbil',
      'chuột degu', 'degu',
      'chuột cảnh', 'chuột fancy',
      'pet mouse', 'pet mice', 'fancy mouse',
      'pet rat', 'fancy rat',

      'nhím cảnh', 'nhím kiểng', 'nhím lùn',
      'nhím lùn châu Phi', 'pet hedgehog',
      'african pygmy hedgehog',
      'chồn ferret', 'chồn sương', 'ferret',
      'sóc cảnh', 'sóc kiểng', 'pet squirrel',
      'sóc bay Úc', 'sóc bay sugar glider', 'sugar glider',

      'chim cảnh', 'chim kiểng', 'chim nuôi',
      'pet bird', 'companion bird',
      'vẹt', 'vẹt cảnh', 'parrot',
      'vẹt yến phụng', 'yến phụng', 'budgie',
      'budgerigar', 'vẹt cockatiel', 'cockatiel',
      'vẹt lovebird', 'lovebird', 'vẹt mẫu đơn',
      'vẹt ngực hồng', 'vẹt má vàng',
      'vẹt xích', 'vẹt ringneck',
      'vẹt conure', 'conure',
      'vẹt sun conure', 'vẹt green cheek',
      'vẹt macaw', 'macaw',
      'vẹt cockatoo', 'cockatoo',
      'vẹt xám châu Phi', 'african grey parrot',
      'vẹt amazon', 'amazon parrot',
      'vẹt eclectus', 'eclectus parrot',
      'chim hoàng yến', 'canary bird',
      'chim manh manh', 'zebra finch',
      'chim sắc Nhật', 'society finch',
      'chim bảy màu', 'gouldian finch',
      'chim chào mào', 'chim chích chòe',
      'chim họa mi', 'chim vành khuyên',
      'chim sáo', 'chim cu gáy',
      'bồ câu cảnh', 'pet pigeon',
      'gà cảnh', 'gà kiểng', 'gà tre cảnh',
      'vịt cảnh', 'vịt kiểng', 'pet duck',

      'cá cảnh', 'cá kiểng', 'cá nuôi cảnh',
      'aquarium fish', 'ornamental fish', 'pet fish',
      'cá vàng', 'goldfish',
      'cá ba đuôi', 'cá ranchu', 'cá oranda',
      'cá đầu lân', 'cá lan thọ',
      'cá betta', 'betta fish', 'cá xiêm', 'cá lia thia',
      'cá bảy màu', 'guppy', 'guppies',
      'cá molly', 'molly fish',
      'cá platy', 'platy fish',
      'cá kiếm cảnh', 'swordtail fish',
      'cá neon', 'neon tetra', 'cardinal tetra',
      'cá sóc đầu đỏ', 'rummy nose tetra',
      'cá tam giác', 'harlequin rasbora',
      'cá ngựa vằn', 'zebra danio',
      'cá thần tiên', 'freshwater angelfish',
      'cá đĩa', 'discus fish',
      'cá koi', 'koi fish',
      'cá rồng', 'arowana',
      'cá la hán', 'flowerhorn',
      'cá oscar', 'oscar fish',
      'cá hồng két', 'blood parrot cichlid',
      'cá ali', 'african cichlid',
      'cá chuột cảnh', 'corydoras',
      'cá otto', 'otocinclus',
      'cá tỳ bà cảnh', 'pleco',
      'cá sặc cảnh', 'gourami',
      'cá lóc cảnh', 'ornamental snakehead',

      'cá cảnh biển', 'cá cảnh nước mặn',
      'marine aquarium fish', 'saltwater aquarium fish',
      'cá hề', 'clownfish',
      'cá đuôi gai cảnh', 'blue tang',
      'cá thia cảnh', 'damselfish',
      'cá bống cảnh biển', 'marine goby',
      'cá ngựa cảnh', 'pet seahorse',

      'tép cảnh', 'tép kiểng', 'tép thủy sinh',
      'tép cherry', 'tép ong', 'tép amano',
      'cherry shrimp', 'crystal shrimp', 'amano shrimp',
      'aquarium shrimp', 'ornamental shrimp',
      'ốc cảnh', 'ốc thủy sinh', 'aquarium snail',
      'ốc nerita', 'nerite snail',
      'ốc táo cảnh', 'mystery snail',
      'ốc ramshorn', 'ramshorn snail',
      'cua cảnh', 'cua vampire', 'vampire crab',
      'tôm crayfish cảnh', 'pet crayfish',
      'tôm hùm đất cảnh',
      'cua ẩn sĩ', 'ốc mượn hồn', 'hermit crab',
      'sứa cảnh', 'pet jellyfish',

      'rùa cảnh', 'rùa kiểng', 'rùa cưng',
      'pet turtle', 'pet tortoise',
      'rùa nước cảnh', 'rùa cạn cảnh',
      'rùa sulcata', 'sulcata tortoise',
      'rùa sao Ấn Độ', 'indian star tortoise',
      'rùa chân đỏ', 'red footed tortoise',
      'rùa Hermann', 'hermann tortoise',
      'rùa Nga', 'russian tortoise',
      'rùa bản đồ', 'map turtle',
      'rùa xạ hương', 'musk turtle',

      'bò sát cảnh', 'bò sát nuôi cảnh', 'pet reptile',
      'thằn lằn cảnh', 'pet lizard',
      'tắc kè cảnh', 'pet gecko',
      'tắc kè báo', 'leopard gecko',
      'tắc kè mào', 'crested gecko',
      'tắc kè đuôi béo', 'african fat tailed gecko',
      'rồng Úc', 'bearded dragon',
      'rồng Nam Mỹ', 'iguana',
      'thằn lằn lưỡi xanh', 'blue tongued skink',
      'tắc kè hoa cảnh', 'pet chameleon',

      'rắn cảnh', 'rắn kiểng', 'pet snake',
      'rắn ngô', 'corn snake',
      'rắn vua cảnh', 'kingsnake',
      'rắn sữa', 'milk snake',
      'trăn bóng', 'ball python',
      'trăn cảnh', 'pet python',
      'rắn hognose', 'hognose snake',

      'ếch cảnh', 'ếch kiểng', 'pet frog',
      'ếch pacman', 'pacman frog',
      'ếch cây cảnh', 'pet tree frog',
      'ếch cây White', 'whites tree frog',
      'kỳ giông cảnh', 'pet salamander',
      'axolotl', 'kỳ giông Mexico',
      'cá khủng long sáu sừng',
      'sa giông cảnh', 'pet newt',

      'côn trùng cảnh', 'pet insect',
      'nhện cảnh', 'nhện tarantula', 'tarantula',
      'nhện nhảy cảnh', 'pet jumping spider',
      'bọ cạp cảnh', 'pet scorpion',
      'bọ ngựa cảnh', 'pet mantis',
      'bọ que cảnh', 'stick insect',
      'bọ lá cảnh', 'leaf insect',
      'bọ cánh cứng cảnh', 'pet beetle',
      'bọ sừng cảnh', 'rhinoceros beetle',
      'bọ kẹp kìm cảnh', 'stag beetle',
      'kiến cảnh', 'nuôi kiến', 'ant colony', 'ant farm',
      'ốc sên cảnh', 'pet land snail',
      'cuốn chiếu cảnh', 'pet millipede',
      'bọ bi cảnh', 'pet isopod',

      'thức ăn thú cưng', 'thức ăn vật nuôi',
      'thức ăn cho chó', 'thức ăn cho mèo',
      'thức ăn hamster', 'thức ăn cho thỏ',
      'thức ăn chim cảnh', 'thức ăn cá cảnh',
      'thức ăn rùa cảnh', 'thức ăn bò sát',
      'pet food', 'dog food', 'cat food',
      'bird food', 'fish food', 'reptile food',
      'rabbit food', 'hamster food',
      'thú y', 'bác sĩ thú y', 'phòng khám thú y',
      'bệnh viện thú y', 'veterinary', 'vet clinic',
      'tiêm phòng thú cưng', 'pet vaccination',
      'spa thú cưng', 'pet grooming',
      'trông giữ thú cưng', 'pet boarding',
    ],

    // Học tập, mua sắm cá nhân và làm đẹp.
    'education': [
      'học phí', 'học thêm', 'khóa học', 'khóa đào tạo', 'trường học',
      'sách', 'vở', 'bút', 'đồ dùng học tập', 'lệ phí thi', 'ngoại ngữ',
      'đại học', 'giáo dục', 'education', 'school', 'course', 'tuition',
      'book', 'online course',
    ],
    'personal_belongings': [
      'quần áo', 'áo', 'quần', 'váy', 'đầm', 'giày', 'dép', 'túi xách',
      'ba lô', 'balo', 'đồng hồ', 'kính', 'mỹ phẩm', 'dầu gội', 'sữa tắm',
      'kem đánh răng', 'đồ cá nhân', 'mua sắm', 'shopping', 'clothes',
      'shoes', 'bag', 'cosmetics', 'personal care', 'skincare',
    ],
    'beautify': [
      'làm đẹp', 'cắt tóc', 'uốn tóc', 'nhuộm tóc', 'gội đầu', 'spa',
      'massage', 'chăm sóc da', 'chăm sóc tóc', 'nail', 'làm móng',
      'thẩm mỹ', 'beauty', 'salon', 'haircut', 'facial', 'massage',
    ],

    // Thể thao, vui chơi, quà tặng và dịch vụ online.
    'sport': [
      'thể thao', 'gym', 'tập gym', 'yoga', 'bóng đá', 'cầu lông',
      'bơi', 'sân bóng', 'phí sân', 'dụng cụ thể thao', 'sport', 'fitness',
      'workout', 'swimming',
    ],
    'fun_play': [
      'giải trí', 'vui chơi', 'đi chơi', 'du lịch', 'karaoke', 'xem phim',
      'rạp phim', 'vé phim', 'concert', 'ca nhạc', 'khu vui chơi',
      'công viên', 'game', 'trò chơi', 'entertainment', 'movie', 'travel',
      'tour', 'holiday',
    ],
    'gifts_donations': [
      'quà', 'quà sinh nhật', 'quà cưới', 'mừng cưới', 'thăm hỏi',
      'từ thiện', 'ủng hộ', 'quyên góp', 'biếu', 'tặng', 'gift',
      'donation', 'charity', 'present',
    ],
    'online_services': [
      'dịch vụ online', 'netflix', 'spotify', 'youtube premium', 'icloud',
      'google one', 'phần mềm', 'app', 'thuê bao', 'subscription',
      'online service', 'streaming', 'software subscription',
    ],

    // Đầu tư, vay, nợ và lãi.
    'invest': [
      'đầu tư', 'mua cổ phiếu', 'cổ phiếu', 'chứng khoán', 'quỹ đầu tư',
      'tiết kiệm', 'gửi tiết kiệm', 'mua vàng', 'crypto', 'bitcoin',
      'invest', 'stock', 'fund', 'savings', 'gold',
    ],
    'debt_collection': [
      'thu nợ', 'người khác trả nợ', 'nhận tiền trả nợ', 'thu hồi nợ',
      'debt collection', 'collect debt',
    ],
    'borrow': [
      'vay tiền', 'đi vay', 'khoản vay', 'vay ngân hàng', 'mượn tiền',
      'borrow', 'borrowing', 'bank loan',
    ],
    'loan': [
      'cho vay', 'cho mượn', 'đưa người khác vay', 'loan', 'lend', 'lending',
    ],
    'pay': [
      'trả nợ', 'thanh toán nợ', 'trả góp', 'trả khoản vay', 'tất toán',
      'pay debt', 'repay', 'installment', 'debt payment',
    ],
    'pay_interest': [
      'lãi vay', 'tiền lãi', 'lãi ngân hàng', 'phí lãi', 'interest',
      'loan interest', 'bank interest',
    ],
    'earn_profit': [
      'lợi nhuận', 'tiền lời', 'lãi đầu tư', 'cổ tức', 'lãi tiết kiệm',
      'profit', 'dividend', 'investment return',
    ],

    // Thu nhập.
    'salary': [
      'lương', 'nhận lương', 'tiền lương', 'lương tháng', 'lương cơ bản',
      'lương thưởng', 'salary', 'payroll', 'monthly salary', 'wage',
    ],
    'other_income': [
      'thu nhập khác', 'tiền thưởng', 'thưởng', 'hoa hồng', 'tiền tip',
      'tiền bo', 'bán hàng', 'bán đồ', 'làm thêm', 'freelance', 'quà tiền',
      'nhận tiền', 'được cho tiền', 'other income', 'bonus', 'commission',
      'tip', 'freelance income', 'cash received',
    ],
    'other_costs': [
      'chi phí khác', 'khoản khác', 'chi khác', 'chi tiêu khác', 'phí khác',
      'mua linh tinh', 'chi linh tinh', 'không biết xếp vào đâu', 'khác',
      'other cost', 'other expense', 'miscellaneous', 'misc expense',
    ],
  };

  // Mở rộng tự động các cụm tiếng Việt, tiếng Anh, thương hiệu và sản phẩm.
  // Các tổ hợp này được tạo trong cùng file để bộ từ khóa lớn nhưng vẫn dễ
  // bổ sung thêm về sau, thay vì lặp lại hàng nghìn dòng xử lý giống nhau.
  static final Map<String, List<String>> _generatedAliases =
  _buildGeneratedAliases();

  static Map<String, List<String>> _buildGeneratedAliases() {
    final result = <String, List<String>>{};

    void combine(String category, List<String> first, List<String> second) {
      final output = result.putIfAbsent(category, () => <String>[]);
      for (final left in first) {
        for (final right in second) {
          output.add('$left $right');
          output.add('$right $left');
        }
      }
    }

    const food = [
      'bánh mì', 'bánh bao', 'bánh cuốn', 'bánh xèo', 'bánh canh',
      'bánh tráng', 'bánh ngọt', 'bánh kem', 'bánh su', 'bánh tiêu',
      'phở', 'phở bò', 'phở gà', 'bún bò', 'bún chả', 'bún riêu',
      'bún thịt nướng', 'bún đậu', 'hủ tiếu', 'mì quảng', 'mì cay',
      'mì xào', 'mì gói', 'cơm tấm', 'cơm gà', 'cơm chiên', 'cơm rang',
      'cơm hộp', 'cháo', 'xôi', 'lẩu', 'lẩu thái', 'lẩu bò', 'nướng',
      'gà rán', 'gà nướng', 'vịt quay', 'sườn nướng', 'hải sản', 'ốc',
      'tôm', 'cua', 'cá', 'thịt bò', 'thịt heo', 'thịt gà', 'trứng',
      'rau', 'trái cây', 'hoa quả', 'đồ ăn', 'thức ăn', 'đồ uống',
      'nước suối', 'nước ngọt', 'coca', 'pepsi', 'trà sữa', 'trà đào',
      'trà chanh', 'cà phê', 'bạc xỉu', 'espresso', 'cappuccino', 'latte',
      'sinh tố', 'nước ép', 'bia', 'rượu', 'snack', 'bắp rang', 'kem',
      'pizza', 'burger', 'hot dog', 'sushi', 'ramen', 'pasta', 'salad',
      'sandwich', 'fried chicken', 'noodles', 'rice', 'breakfast', 'lunch',
      'dinner', 'dessert', 'beverage','đi nhậu', 'ăn', 'nhậu', 'uống'
    ];
    const foodBrands = [
      'KFC', 'Lotteria', 'McDonalds', 'Burger King', 'Pizza Hut', 'Dominos',
      'Jollibee', 'Highlands', 'Phuc Long', 'Starbucks', 'The Coffee House',
      'Trung Nguyen', 'Gong Cha', 'KOI Thé', 'TocoToco', 'Mixue', 'AhaMove',
      'GrabFood', 'ShopeeFood', 'BeFood', 'Baemin', 'GoFood', 'Circle K',
      'WinMart', 'VinMart', 'CoopMart', 'Bach Hoa Xanh', 'Aeon', 'Lotte',
      'Mega Market', 'GS25', 'FamilyMart', '7 Eleven', 'Texas Chicken',
      'The Pizza Company', 'Dookki', 'King BBQ', 'Gogi House', 'Manwah',
      'Hutong', 'ThaiExpress', 'Popeyes',
    ];

    const clothes = [
      'áo', 'áo thun', 'áo sơ mi', 'áo khoác', 'áo len', 'áo hoodie',
      'áo polo', 'áo vest', 'áo dài', 'quần', 'quần jean', 'quần kaki',
      'quần short', 'quần tây', 'quần thể thao', 'váy', 'đầm', 'bikini',
      'đồ bơi', 'đồ lót', 'đồ ngủ', 'đồng phục', 'giày', 'giày thể thao',
      'giày cao gót', 'giày tây', 'dép', 'sandal', 'boots', 'sneaker',
      'túi xách', 'ba lô', 'balo', 'ví', 'thắt lưng', 'mũ', 'nón', 'kính',
      'đồng hồ', 'trang sức', 'nhẫn', 'vòng tay', 'bông tai', 'khăn',
      'clothes', 'shirt', 't-shirt', 'jacket', 'dress', 'skirt', 'jeans',
      'shorts', 'swimwear', 'bikini', 'underwear', 'shoes', 'sneakers',
      'sandals', 'handbag', 'backpack', 'wallet', 'watch', 'accessories',
    ];
    const fashionBrands = [
      'Uniqlo', 'H&M', 'Zara', 'Adidas', 'Nike', 'Puma', 'Converse',
      'Vans', 'Gucci', 'Prada', 'Chanel', 'Dior', 'Louis Vuitton',
      'Hermes', 'Lacoste', 'Levis', 'An Phuoc', 'Routine', 'Canifa',
      'IVY Moda', 'Yody', 'Owen', 'Coolmate', 'Juno', 'Biti\'s', 'Pedro',
      'Charles Keith', 'Havaianas', 'The North Face', 'New Balance',
      'Balenciaga', 'Burberry', 'Tommy Hilfiger', 'Calvin Klein', 'GU',
    ];

    const household = [
      'nồi', 'nồi cơm điện', 'nồi chiên không dầu', 'nồi áp suất', 'chảo',
      'bếp gas', 'bếp điện', 'bếp từ', 'lò vi sóng', 'lò nướng', 'ấm nước',
      'ấm siêu tốc', 'máy xay', 'máy ép', 'máy pha cà phê', 'tủ lạnh',
      'máy giặt', 'máy sấy', 'máy hút bụi', 'robot hút bụi', 'quạt',
      'điều hòa', 'tivi', 'tủ', 'bàn', 'ghế', 'giường', 'nệm', 'gối',
      'chăn', 'ga giường', 'rèm cửa', 'đèn', 'bóng đèn', 'ổ điện', 'dây điện',
      'bát', 'chén', 'đũa', 'muỗng', 'ly', 'cốc', 'dao', 'thớt', 'xô',
      'chổi', 'cây lau nhà', 'nước rửa chén', 'bột giặt', 'nước xả',
      'nước lau sàn', 'giấy vệ sinh', 'khăn giấy', 'household', 'appliance',
      'rice cooker', 'air fryer', 'refrigerator', 'washing machine', 'fan',
      'air conditioner', 'television', 'vacuum cleaner', 'furniture',
    ];
    const homeBrands = [
      'Samsung', 'LG', 'Sony', 'Panasonic', 'Toshiba', 'Sharp', 'Electrolux',
      'Philips', 'Bosch', 'Tefal', 'LocknLock', 'Kangaroo', 'Sunhouse',
      'Elmich', 'Bluestone', 'Kitchenaid', 'Dyson', 'Xiaomi', 'Daikin',
      'Midea', 'Aqua', 'Hitachi', 'Ariete', 'Cosori', 'Nitori', 'Ikea',
      'Dien May Xanh', 'Nguyen Kim', 'Aeon Home', 'Miniso',
    ];

    const electronics = [
      'điện thoại', 'smartphone', 'iphone', 'ipad', 'tablet', 'laptop',
      'máy tính', 'màn hình', 'bàn phím', 'chuột', 'tai nghe', 'loa',
      'sạc', 'cáp sạc', 'pin dự phòng', 'ốp điện thoại', 'camera',
      'máy in', 'USB', 'ổ cứng', 'thẻ nhớ', 'router', 'wifi', 'webcam',
      'phone', 'computer', 'monitor', 'keyboard', 'mouse', 'headphone',
      'speaker', 'charger', 'power bank', 'hard drive', 'memory card',
    ];
    const technologyBrands = [
      'Apple', 'iPhone', 'Samsung', 'Oppo', 'Vivo', 'Xiaomi', 'Huawei',
      'Google Pixel', 'OnePlus', 'Dell', 'HP', 'Lenovo', 'Asus', 'Acer',
      'MSI', 'MacBook', 'Microsoft', 'Logitech', 'JBL', 'Anker', 'Baseus',
      'Sony', 'Canon', 'Nikon', 'GoPro', 'TP-Link', 'Kingston', 'Seagate',
      'Western Digital', 'Razer', 'Corsair',
    ];

    const health = [
      'thuốc', 'thuốc cảm', 'thuốc đau đầu', 'thuốc ho', 'vitamin',
      'thực phẩm chức năng', 'khẩu trang', 'nhiệt kế', 'băng cá nhân',
      'khám bệnh', 'khám răng', 'nha khoa', 'bệnh viện', 'bác sĩ',
      'xét nghiệm', 'siêu âm', 'tiêm phòng', 'kính thuốc', 'health',
      'medicine', 'pharmacy', 'doctor', 'hospital', 'dental', 'vitamin',
    ];
    const healthBrands = [
      'Long Chau', 'Pharmacity', 'An Khang', 'Guardian', 'Medicare',
      'Hasaki', 'Abbott', 'Ensure', 'Blackmores', 'Kirkland', 'DHC',
      'Panadol', 'Hapacol', 'Decolgen', 'Berocca', 'Pigeon', 'Cetaphil',
    ];

    const transport = [
      'taxi', 'grab', 'grabcar', 'grabbike', 'grabfood delivery', 'be',
      'gojek', 'uber', 'xe ôm', 'xe máy', 'xe buýt', 'bus', 'metro',
      'tàu điện', 'tàu hỏa', 'máy bay', 'vé máy bay', 'vé xe', 'vé tàu',
      'xăng', 'dầu nhớt', 'rửa xe', 'gửi xe', 'bãi xe', 'phí cầu đường',
      'parking', 'fuel', 'gasoline', 'transport', 'motorbike', 'car',
    ];
    const transportBrands = [
      'Grab', 'Be', 'Gojek', 'Uber', 'Mai Linh', 'Vinasun', 'VinFast',
      'Honda', 'Yamaha', 'Toyota', 'Mazda', 'Ford', 'Hyundai', 'Kia',
      'Thaco', 'Petrolimex', 'PVOil', 'Shell', 'Caltex', 'Circle K',
      'Vietnam Airlines', 'Vietjet', 'Bamboo Airways', 'Futa Bus', 'Phuong Trang',
    ];

    combine('eating', food, foodBrands);
    combine('personal_belongings', clothes, fashionBrands);
    combine('housewares', household, homeBrands);
    combine('personal_belongings', electronics, technologyBrands);
    combine('physical_examination', health, healthBrands);
    combine('move', transport, transportBrands);

    return result;
  }

  static CategoryMatch? find(String input) {
    final normalizedInput = _normalize(input);
    if (normalizedInput.isEmpty) return null;

    CategoryMatch? best;
    var bestAliasLength = 0;

    for (var index = 0; index < listType.length; index++) {
      final item = listType[index];
      final key = item['title'] ?? '';
      if (key.isEmpty || item['isParent'] == 'true' || item['image'] == null) continue;

      final aliases = <String>{
        key,
        ...?_aliases[key],
        ...?_generatedAliases[key],
      };
      for (final alias in aliases) {
        final normalizedAlias = _normalize(alias);
        if (normalizedAlias.isEmpty || !_matches(normalizedInput, normalizedAlias)) {
          continue;
        }

        // Cụm từ dài cụ thể hơn từ đơn. Ví dụ "tiền gas" thắng "gas".
        final length = normalizedAlias.length;
        // Prefer an exact accented phrase: dừa and đũa both fold to
        // "dua", but represent very different items.
        final exact = RegExp(
          '(^|\\s)${RegExp.escape(alias.toLowerCase())}(?=\\s|\$)',
        ).hasMatch(input.toLowerCase().replaceAll(
          RegExp(r'[.,!?;:/()\[\]{}]+'), ' ',
        ));
        final score = (0.62 + (length / 80) + (exact ? 0.08 : 0))
            .clamp(0.62, 0.98).toDouble();
        if (best == null || score > best.confidence ||
            (score == best.confidence && length > bestAliasLength)) {
          best = CategoryMatch(index, key, score);
          bestAliasLength = length;
        }
      }
    }
    return best;
  }

  static bool _matches(String input, String alias) {
    return RegExp('(^|\\s)${RegExp.escape(alias)}(?=\\s|\$)')
        .hasMatch(input);
  }

  static String _normalize(String value) {
    var result = value.toLowerCase();
    const replacements = <String, String>{
      'à': 'a', 'á': 'a', 'ạ': 'a', 'ả': 'a', 'ã': 'a', 'â': 'a', 'ầ': 'a',
      'ấ': 'a', 'ậ': 'a', 'ẩ': 'a', 'ẫ': 'a', 'ă': 'a', 'ằ': 'a', 'ắ': 'a',
      'ặ': 'a', 'ẳ': 'a', 'ẵ': 'a', 'è': 'e', 'é': 'e', 'ẹ': 'e', 'ẻ': 'e',
      'ẽ': 'e', 'ê': 'e', 'ề': 'e', 'ế': 'e', 'ệ': 'e', 'ể': 'e', 'ễ': 'e',
      'ì': 'i', 'í': 'i', 'ị': 'i', 'ỉ': 'i', 'ĩ': 'i', 'ò': 'o', 'ó': 'o',
      'ọ': 'o', 'ỏ': 'o', 'õ': 'o', 'ô': 'o', 'ồ': 'o', 'ố': 'o', 'ộ': 'o',
      'ổ': 'o', 'ỗ': 'o', 'ơ': 'o', 'ờ': 'o', 'ớ': 'o', 'ợ': 'o', 'ở': 'o',
      'ỡ': 'o', 'ù': 'u', 'ú': 'u', 'ụ': 'u', 'ủ': 'u', 'ũ': 'u', 'ư': 'u',
      'ừ': 'u', 'ứ': 'u', 'ự': 'u', 'ử': 'u', 'ữ': 'u', 'ỳ': 'y', 'ý': 'y',
      'ỵ': 'y', 'ỷ': 'y', 'ỹ': 'y', 'đ': 'd',
    };
    replacements.forEach((from, to) => result = result.replaceAll(from, to));
    return result
        .replaceAll(RegExp(r'[.,!?;:/()\[\]{}]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
