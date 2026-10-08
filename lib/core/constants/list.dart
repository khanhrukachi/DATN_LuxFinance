List<Map<String, String>> listType = [
  // Root: Chi tiêu
  {'id': 'expense', 'parent': '', 'type': 'expense', 'image': 'assets/icons/wallet.png', 'title': 'expense', 'level': '0', 'isParent': 'true'},

  {'id': 'expense_living', 'parent': 'expense', 'type': 'expense', 'image': 'assets/icons/house.png', 'title': 'expense_living', 'level': '1', 'isParent': 'true'},
  {'id': 'eating', 'parent': 'expense_living', 'type': 'expense', 'image': 'assets/icons/eat.png', 'title': 'eating', 'level': '2', 'isParent': 'false'},
  {'id': 'move', 'parent': 'expense_living', 'type': 'expense', 'image': 'assets/icons/taxi.png', 'title': 'move', 'level': '2', 'isParent': 'false'},
  {'id': 'market', 'parent': 'expense_living', 'type': 'expense', 'image': 'assets/icons/box.png', 'title': 'market', 'level': '2', 'isParent': 'false'},
  {'id': 'telephone_fee', 'parent': 'expense_living', 'type': 'expense', 'image': 'assets/icons/phone.png', 'title': 'telephone_fee', 'level': '2', 'isParent': 'false'},

  {'id': 'expense_unexpected', 'parent': 'expense', 'type': 'expense', 'image': 'assets/icons/box.png', 'title': 'expense_unexpected', 'level': '1', 'isParent': 'true'},
  {'id': 'vehicle_maintenance', 'parent': 'expense_unexpected', 'type': 'expense', 'image': 'assets/icons/tools.png', 'title': 'vehicle_maintenance', 'level': '2', 'isParent': 'false'},
  {'id': 'physical_examination', 'parent': 'expense_unexpected', 'type': 'expense', 'image': 'assets/icons/doctor.png', 'title': 'physical_examination', 'level': '2', 'isParent': 'false'},
  {'id': 'repair_and_decorate_the_house', 'parent': 'expense_unexpected', 'type': 'expense', 'image': 'assets/icons/house_2.png', 'title': 'repair_and_decorate_the_house', 'level': '2', 'isParent': 'false'},
  {'id': 'housewares', 'parent': 'expense_unexpected', 'type': 'expense', 'image': 'assets/icons/armchair.png', 'title': 'housewares', 'level': '2', 'isParent': 'false'},
  {'id': 'personal_belongings', 'parent': 'expense_unexpected', 'type': 'expense', 'image': 'assets/icons/toothbrush.png', 'title': 'personal_belongings', 'level': '2', 'isParent': 'false'},
  {'id': 'pet', 'parent': 'expense_unexpected', 'type': 'expense', 'image': 'assets/icons/pet.png', 'title': 'pet', 'level': '2', 'isParent': 'false'},
  {'id': 'other_costs', 'parent': 'expense_unexpected', 'type': 'expense', 'image': 'assets/icons/box.png', 'title': 'other_costs', 'level': '2', 'isParent': 'false'},
  {'id': 'sport', 'parent': 'expense_unexpected', 'type': 'expense', 'image': 'assets/icons/sports.png', 'title': 'sport', 'level': '2', 'isParent': 'false'},
  {'id': 'fun_play', 'parent': 'expense_unexpected', 'type': 'expense', 'image': 'assets/icons/game-pad.png', 'title': 'fun_play', 'level': '2', 'isParent': 'false'},
  {'id': 'beautify', 'parent': 'expense_unexpected', 'type': 'expense', 'image': 'assets/icons/diamond.png', 'title': 'beautify', 'level': '2', 'isParent': 'false'},
  {'id': 'online_services', 'parent': 'expense_unexpected', 'type': 'expense', 'image': 'assets/icons/card-payment.png', 'title': 'online_services', 'level': '2', 'isParent': 'false'},
  {'id': 'gifts_donations', 'parent': 'expense_unexpected', 'type': 'expense', 'image': 'assets/icons/give-love.png', 'title': 'gifts_donations', 'level': '2', 'isParent': 'false'},
  {'id': 'gas_money', 'parent': 'expense_unexpected', 'type': 'expense', 'image': 'assets/icons/gas.png', 'title': 'gas_money', 'level': '2', 'isParent': 'false'},

  {'id': 'expense_fixed', 'parent': 'expense', 'type': 'expense', 'image': 'assets/icons/electricity.png', 'title': 'expense_fixed', 'level': '1', 'isParent': 'true'},
  {'id': 'rent_house', 'parent': 'expense_fixed', 'type': 'expense', 'image': 'assets/icons/house.png', 'title': 'rent_house', 'level': '2', 'isParent': 'false'},
  {'id': 'water_money', 'parent': 'expense_fixed', 'type': 'expense', 'image': 'assets/icons/water.png', 'title': 'water_money', 'level': '2', 'isParent': 'false'},
  {'id': 'electricity_bill', 'parent': 'expense_fixed', 'type': 'expense', 'image': 'assets/icons/electricity.png', 'title': 'electricity_bill', 'level': '2', 'isParent': 'false'},
  {'id': 'internet_money', 'parent': 'expense_fixed', 'type': 'expense', 'image': 'assets/icons/internet.png', 'title': 'internet_money', 'level': '2', 'isParent': 'false'},
  {'id': 'tv_money', 'parent': 'expense_fixed', 'type': 'expense', 'image': 'assets/icons/tv.png', 'title': 'tv_money', 'level': '2', 'isParent': 'false'},

  {'id': 'investment_saving', 'parent': 'expense', 'type': 'expense', 'image': 'assets/icons/stats.png', 'title': 'investment_saving', 'level': '1', 'isParent': 'true'},
  {'id': 'invest', 'parent': 'investment_saving', 'type': 'expense', 'image': 'assets/icons/stats.png', 'title': 'invest', 'level': '2', 'isParent': 'false'},
  {'id': 'education', 'parent': 'investment_saving', 'type': 'expense', 'image': 'assets/icons/education.png', 'title': 'education', 'level': '2', 'isParent': 'false'},
  {'id': 'insurance', 'parent': 'investment_saving', 'type': 'expense', 'image': 'assets/icons/health-insurance.png', 'title': 'insurance', 'level': '2', 'isParent': 'false'},

  {'id': 'loan_borrow', 'parent': 'expense', 'type': 'expense', 'image': 'assets/icons/loan.png', 'title': 'loan_borrow', 'level': '1', 'isParent': 'true'},
  {'id': 'loan', 'parent': 'loan_borrow', 'type': 'expense', 'image': 'assets/icons/loan.png', 'title': 'loan', 'level': '2', 'isParent': 'false'},
  {'id': 'pay', 'parent': 'loan_borrow', 'type': 'expense', 'image': 'assets/icons/pay.png', 'title': 'pay', 'level': '2', 'isParent': 'false'},
  {'id': 'pay_interest', 'parent': 'loan_borrow', 'type': 'expense', 'image': 'assets/icons/commission.png', 'title': 'pay_interest', 'level': '2', 'isParent': 'false'},

  // Root: Thu nhập
  {'id': 'income', 'parent': '', 'type': 'income', 'image': 'assets/icons/money-bag.png', 'title': 'income', 'level': '0', 'isParent': 'true'},
  {'id': 'debt_collection', 'parent': 'income', 'type': 'income', 'image': 'assets/icons/coins.png', 'title': 'debt_collection', 'level': '1', 'isParent': 'false'},
  {'id': 'borrow', 'parent': 'income', 'type': 'income', 'image': 'assets/icons/borrow.png', 'title': 'borrow', 'level': '1', 'isParent': 'false'},
  {'id': 'earn_profit', 'parent': 'income', 'type': 'income', 'image': 'assets/icons/percentage.png', 'title': 'earn_profit', 'level': '1', 'isParent': 'false'},
  {'id': 'salary', 'parent': 'income', 'type': 'income', 'image': 'assets/icons/money.png', 'title': 'salary', 'level': '1', 'isParent': 'false'},
  {'id': 'other_income', 'parent': 'income', 'type': 'income', 'image': 'assets/icons/money-bag.png', 'title': 'other_income', 'level': '1', 'isParent': 'false'},
];



List<String> moneyList = ["all", "bigger", "smaller", "about2", "exactly"];
List<String> timeList = ["all", "after", "before", "about2", "exactly"];
List<String> groupList = ["all", "all_earnings", "all_expenses"];

List<String> listDayOfWeek = [
  "monday",
  "tuesday",
  "wednesday",
  "thursday",
  "friday",
  "saturday",
  "sunday"
];

List<String> listDayOfWeekAcronym = [
  "mon",
  "tue",
  "wed",
  "thu",
  "fri",
  "sat",
  "sun"
];

List<String> listMonthOfYear = [
  "january",
  "february",
  "march",
  "april",
  "may",
  "june",
  "july",
  "august",
  "september",
  "october",
  "november",
  "december"
];

List<String> listMonthOfYearAcronym = [
  "jan",
  "feb",
  "mar",
  "apr",
  "maya",
  "jun",
  "jul",
  "aug",
  "sep",
  "oct",
  "nov",
  "dec"
];
