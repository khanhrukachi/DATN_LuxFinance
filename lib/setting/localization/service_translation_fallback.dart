const serviceFallbackTranslations = <String, Map<String, String>>{
  'vi': <String, String>{
    'service_login_required': 'Bạn cần đăng nhập',
    'service_session_changed':
        'Phiên đăng nhập đã thay đổi. Hãy mở lại màn hình.',
    'service_user_missing': 'Thông tin người dùng chưa tồn tại',
    'service_wallet_invalid': 'Số dư ví không hợp lệ',
    'service_contact_name_required': 'Tên không được trống',
    'service_contact_has_debts': 'Đối tượng còn khoản nợ, không thể xóa',
    'service_amount_invalid': 'Số tiền không hợp lệ',
    'service_debt_direction_invalid': 'Loại nợ không hợp lệ',
    'service_due_before_date': 'Hạn trả phải từ ngày giao dịch',
    'service_amount_below_paid': 'Số tiền nợ không thể nhỏ hơn số đã trả',
    'service_contact_missing': 'Đối tượng không tồn tại',
    'service_debt_deleted': 'Khoản nợ đã bị xóa',
    'service_debt_create_conflict':
        'Khoản nợ đã được lưu với thông tin khác. Hãy đóng màn hình và mở lại',
    'service_wallet_unlink_forbidden':
        'Khoản đã liên kết ví không thể bỏ liên kết',
    'service_debt_changed': 'Dữ liệu đã thay đổi. Hãy mở lại khoản nợ',
    'service_paid_contact_locked':
        'Đã có thanh toán, không thể đổi đối tượng hoặc loại nợ',
    'service_debt_date_after_payment':
        'Ngày vay không được sau ngày thanh toán đã ghi',
    'service_payment_duplicate_conflict':
        'Lần thanh toán này đã lưu. Hãy đóng và xem lại lịch sử',
    'service_payment_amount_invalid': 'Số tiền trả phải từ 1 đến số còn nợ',
    'service_payment_date_before_debt': 'Ngày trả không được trước ngày vay',
    'service_payment_limit': 'Khoản nợ đã đạt giới hạn 500 lần thanh toán',
    'service_debt_delete_changed':
        'Dữ liệu đã thay đổi. Hãy mở lại trước khi xóa',
    'service_spending_not_owned': 'Không có quyền sửa giao dịch này',
    'service_category_invalid': 'Danh mục không hợp lệ',
    'service_use_debt_book':
        'Vay, cho vay, thu/trả nợ được quản lý trong Sổ nợ, không thêm vào chi tiêu.',
    'service_spending_id_missing': 'Giao dịch chưa có id',
    'service_spending_deleted': 'Giao dịch đã bị xóa',
    'service_spending_changed':
        'Giao dịch đã thay đổi từ khi mở màn hình. Hãy mở lại',
    'service_spending_delete_changed':
        'Giao dịch đã thay đổi. Hãy mở lại trước khi xóa',
    'service_budget_missing': 'Budget document không tồn tại!',
    'service_notification_title_required': 'Tiêu đề không được trống.',
    'service_notification_not_ready': 'Gọi initialize() trước.',
    'service_dedup_key_invalid': 'Khóa chống trùng cần dài từ 1 đến 800 byte.',
    'service_time_invalid': 'Giờ phải từ 0–23, phút từ 0–59.',
    'service_schedule_future_required': 'Thời điểm nhắc phải ở tương lai.',
    'service_exchange_load_failed': 'Không tải được dữ liệu tỷ giá.',
    'service_country_load_failed':
        'Không tải được dữ liệu quốc gia hoặc ký hiệu tiền tệ.',
    'service_symbol_load_failed': 'Không tải được ký hiệu tiền tệ.',
    'service_phone_digits': 'Số điện thoại chỉ được chứa chữ số (0–9).',
    'service_phone_format':
        'Sai định dạng: nhập 10 hoặc 11 chữ số, bắt đầu bằng 0.',
    'service_channel_name': 'Thông báo LuxFinance',
    'service_channel_description': 'Cảnh báo chi tiêu và gợi ý tài chính',
    'service_daily_title': 'Ghi lại chi tiêu hôm nay',
    'service_daily_body':
        'Cập nhật các khoản thu chi để theo dõi ngân sách của bạn.',
    'service_debt_overdue_title': 'Khoản nợ quá hạn',
    'service_debt_due_title': 'Khoản nợ đến hạn hôm nay',
    'service_debt_due_body': '{name}: {action} {amount}.',
    'service_debt_collect': 'cần thu',
    'service_debt_pay': 'cần trả',
    'service_debt_alarm_title': 'Kiểm tra hạn khoản nợ',
    'service_debt_alarm_body':
        '{name} · Hạn {date}. Mở sổ nợ để kiểm tra số còn {action}.',
    'service_debt_collect_short': 'thu',
    'service_debt_pay_short': 'trả',
    'service_unknown_error': 'Không thực hiện được thao tác. Vui lòng thử lại.',
    'budget_notification_overall': 'Tổng chi tiêu',
    'budget_notification_category': 'Danh mục chi tiêu',
    'budget_notification_near_title': '{category}: sắp hết ngân sách',
    'budget_notification_near_body':
        'Tháng {period}: đã chi {spent}/{limit} ({percent}%). Còn {remaining} trong ngân sách.',
    'budget_notification_reached_title': '{category}: đã dùng hết ngân sách',
    'budget_notification_reached_body':
        'Tháng {period}: đã chi {spent}, bằng hạn mức {limit}. Các khoản chi tiếp theo sẽ vượt ngân sách.',
    'budget_notification_exceeded_title': '{category}: đã vượt ngân sách',
    'budget_notification_exceeded_body':
        'Tháng {period}: đã chi {spent}/{limit}, vượt {over}. Hãy xem lại các khoản chi còn lại trong tháng.',
  },
  'en': <String, String>{
    'service_login_required': 'Please sign in.',
    'service_session_changed':
        'Your sign-in session has changed. Reopen this screen.',
    'service_user_missing': 'Your user profile does not exist.',
    'service_wallet_invalid': 'The wallet balance is invalid.',
    'service_contact_name_required': 'Enter a contact name.',
    'service_contact_has_debts':
        'This contact has debts and cannot be deleted.',
    'service_amount_invalid': 'Enter a valid amount.',
    'service_debt_direction_invalid': 'The debt type is invalid.',
    'service_due_before_date':
        'The due date must be on or after the transaction date.',
    'service_amount_below_paid':
        'The debt amount cannot be less than the amount already paid.',
    'service_contact_missing': 'This contact no longer exists.',
    'service_debt_deleted': 'This debt has been deleted.',
    'service_debt_create_conflict':
        'This debt was saved with different details. Close this screen and reopen it.',
    'service_wallet_unlink_forbidden':
        'A debt linked to the wallet cannot be unlinked.',
    'service_debt_changed': 'This debt has changed. Reopen it before editing.',
    'service_paid_contact_locked':
        'This debt has payments. Its contact and type cannot be changed.',
    'service_debt_date_after_payment':
        'The debt date cannot be after an existing payment date.',
    'service_payment_duplicate_conflict':
        'This payment was already saved. Close this screen and review the history.',
    'service_payment_amount_invalid':
        'The payment must be between 1 and the remaining debt amount.',
    'service_payment_date_before_debt':
        'The payment date cannot be before the debt date.',
    'service_payment_limit': 'This debt has reached the limit of 500 payments.',
    'service_debt_delete_changed':
        'This debt has changed. Reopen it before deleting.',
    'service_spending_not_owned':
        'You do not have permission to change this transaction.',
    'service_category_invalid': 'The category is invalid.',
    'service_use_debt_book':
        'Record borrowing, lending and debt payments in the Debt Book.',
    'service_spending_id_missing': 'This transaction has no ID.',
    'service_spending_deleted': 'This transaction has been deleted.',
    'service_spending_changed':
        'This transaction has changed. Reopen it before editing.',
    'service_spending_delete_changed':
        'This transaction has changed. Reopen it before deleting.',
    'service_budget_missing': 'This budget no longer exists.',
    'service_notification_title_required': 'Enter a notification title.',
    'service_notification_not_ready':
        'Notifications are not ready. Initialize the notification service first.',
    'service_dedup_key_invalid':
        'The notification deduplication key must contain 1 to 800 bytes.',
    'service_time_invalid':
        'The hour must be between 0 and 23, and the minute between 0 and 59.',
    'service_schedule_future_required': 'Choose a reminder time in the future.',
    'service_exchange_load_failed': 'Could not load exchange rates.',
    'service_country_load_failed':
        'Could not load country or currency symbol data.',
    'service_symbol_load_failed': 'Could not load currency symbols.',
    'service_phone_digits': 'The phone number can contain digits only (0–9).',
    'service_phone_format': 'Enter 10 or 11 digits starting with 0.',
    'service_channel_name': 'LuxFinance notifications',
    'service_channel_description': 'Spending alerts and financial insights',
    'service_daily_title': 'Record today’s spending',
    'service_daily_body':
        'Update your income and expenses to keep track of your budget.',
    'service_debt_overdue_title': 'Overdue debt',
    'service_debt_due_title': 'Debt due today',
    'service_debt_due_body': '{name}: {action} {amount}.',
    'service_debt_collect': 'to collect',
    'service_debt_pay': 'to pay',
    'service_debt_alarm_title': 'Check your debt due date',
    'service_debt_alarm_body':
        '{name} · Due {date}. Open the Debt Book to check the amount {action}.',
    'service_debt_collect_short': 'to collect',
    'service_debt_pay_short': 'to pay',
    'service_unknown_error':
        'Could not complete this action. Please try again.',
    'budget_notification_overall': 'Overall spending',
    'budget_notification_category': 'Spending category',
    'budget_notification_near_title': '{category}: budget nearly used up',
    'budget_notification_near_body':
        'For {period}, you have spent {spent} of {limit} ({percent}%). You have {remaining} left.',
    'budget_notification_reached_title': '{category}: budget fully used',
    'budget_notification_reached_body':
        'For {period}, spending of {spent} has reached your {limit} limit. Further spending will exceed the budget.',
    'budget_notification_exceeded_title': '{category}: budget exceeded',
    'budget_notification_exceeded_body':
        'For {period}, you have spent {spent} of {limit}, exceeding the budget by {over}. Review your remaining expenses this month.',
  },
};
