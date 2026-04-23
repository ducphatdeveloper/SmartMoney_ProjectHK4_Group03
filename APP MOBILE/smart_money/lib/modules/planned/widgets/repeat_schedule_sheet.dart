// ===========================================================
// [3.3] RepeatScheduleSheet — Bottom sheet chọn lịch lặp lại
// ===========================================================
// Dùng ở: PlannedFormScreen → bấm row "Lịch lặp lại" → mở sheet này
// Tham số:
//   • initialRepeatType: kiểu lặp ban đầu (null = chưa chọn)
//   • initialInterval: khoảng lặp (mặc định 1)
//   • initialBeginDate: ngày bắt đầu (mặc định hôm nay)
//   • initialDayBitmask: bitmask ngày tuần (chỉ khi weekly)
//   • initialEndDateOption: "FOREVER" | "UNTIL_DATE" | "COUNT"
//   • initialEndDateValue: ngày kết thúc (khi UNTIL_DATE)
//   • initialRepeatCount: số lần lặp (khi COUNT)
//   • isEditing: true = đang sửa, hiện switch bật/tắt
//   • isActive: trạng thái active hiện tại (dùng khi sửa)
//   • onConfirm: callback trả dữ liệu đã chọn về Screen cha
//   • onToggle: callback khi bấm switch → gọi provider.toggle()
// ===========================================================

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:smart_money/core/helpers/format_helper.dart';
import 'package:smart_money/modules/planned/enums/repeat_type.dart';

// ── Kết quả trả về khi bấm XONG ──
class RepeatScheduleResult {
  final int repeatType;         // 1=daily, 2=weekly, 3=monthly, 4=yearly
  final int repeatInterval;     // mỗi N đơn vị
  final DateTime beginDate;     // ngày bắt đầu
  final int? repeatOnDayVal;    // bitmask ngày tuần (chỉ khi weekly)
  final String endDateOption;   // "FOREVER" | "UNTIL_DATE" | "COUNT"
  final DateTime? endDateValue; // ngày kết thúc (khi UNTIL_DATE)
  final int? repeatCount;       // số lần lặp (khi COUNT)

  const RepeatScheduleResult({
    required this.repeatType,
    required this.repeatInterval,
    required this.beginDate,
    this.repeatOnDayVal,
    required this.endDateOption,
    this.endDateValue,
    this.repeatCount,
  });
}

class RepeatScheduleSheet extends StatefulWidget {

  final int? initialRepeatType;       // null = chưa chọn, mặc định monthly
  final int initialInterval;          // mặc định 1
  final DateTime? initialBeginDate;   // null = hôm nay
  final int? initialDayBitmask;       // bitmask ngày tuần
  final String initialEndDateOption;  // mặc định "FOREVER"
  final DateTime? initialEndDateValue;
  final int? initialRepeatCount;
  final bool isEditing;               // true = đang sửa → hiện switch
  final bool isActive;                // trạng thái active hiện tại
  final void Function(RepeatScheduleResult result) onConfirm;
  final VoidCallback? onToggle;       // callback khi bấm switch

  const RepeatScheduleSheet({
    super.key,
    this.initialRepeatType,
    this.initialInterval = 1,
    this.initialBeginDate,
    this.initialDayBitmask,
    this.initialEndDateOption = 'FOREVER',
    this.initialEndDateValue,
    this.initialRepeatCount,
    this.isEditing = false,
    this.isActive = true,
    required this.onConfirm,
    this.onToggle,
  });

  @override
  State<RepeatScheduleSheet> createState() => _RepeatScheduleSheetState();
}

class _RepeatScheduleSheetState extends State<RepeatScheduleSheet> {

  // =============================================
  // [3.3.1] STATE
  // =============================================

  late int _repeatType;             // 1=daily, 2=weekly, 3=monthly, 4=yearly
  late int _interval;               // khoảng lặp (mỗi N...)
  late DateTime _beginDate;         // ngày bắt đầu
  late int _dayBitmask;             // bitmask ngày tuần (weekly)
  late String _endDateOption;       // "FOREVER" | "UNTIL_DATE" | "COUNT"
  DateTime? _endDateValue;          // ngày kết thúc (UNTIL_DATE)
  int? _repeatCount;                // số lần lặp (COUNT)
  late bool _isActive;              // switch bật/tắt (chỉ khi sửa)

  final _intervalController = TextEditingController(); // controller ô nhập số interval
  final _countController = TextEditingController();    // controller ô nhập số lần lặp

  // Map thứ Flutter (1=T2..7=CN) sang bitmask value của FormatHelper
  static const Map<int, int> _dayToBitmask = {
    1: 2,    // Thứ Hai → FormatHelper.monday
    2: 4,    // Thứ Ba → FormatHelper.tuesday
    3: 8,    // Thứ Tư → FormatHelper.wednesday
    4: 16,   // Thứ Năm → FormatHelper.thursday
    5: 32,   // Thứ Sáu → FormatHelper.friday
    6: 64,   // Thứ Bảy → FormatHelper.saturday
    7: 1,    // Chủ Nhật → FormatHelper.sunday
  };

  // Label hiển thị cho 7 ô tròn
  static const List<String> _dayLabels = ['CN', 'TH 2', 'TH 3', 'TH 4', 'TH 5', 'TH 6', 'TH 7'];
  // Bitmask tương ứng với 7 ô tròn (CN=1, T2=2, T3=4, ...)
  static const List<int> _dayBitmaskValues = [1, 2, 4, 8, 16, 32, 64];

  @override
  void initState() {
    super.initState();
    // Khởi tạo state từ props truyền vào
    _repeatType = widget.initialRepeatType ?? RepeatType.monthly.value; // mặc định hàng tháng
    _interval = widget.initialInterval;
    _beginDate = widget.initialBeginDate ?? DateTime.now();
    _isActive = widget.isActive;
    _endDateOption = widget.initialEndDateOption;
    _endDateValue = widget.initialEndDateValue;
    _repeatCount = widget.initialRepeatCount;

    // Bitmask: nếu chưa có → tự chọn thứ hôm nay
    if (widget.initialDayBitmask != null && widget.initialDayBitmask! > 0) {
      _dayBitmask = widget.initialDayBitmask!;
    } else {
      // Mặc định: chọn thứ hôm nay
      final todayWeekday = DateTime.now().weekday; // 1=T2..7=CN
      _dayBitmask = _dayToBitmask[todayWeekday] ?? FormatHelper.monday;
    }

    _intervalController.text = _interval.toString();
    _countController.text = (_repeatCount ?? 1).toString();
  }

  @override
  void dispose() {
    _intervalController.dispose();
    _countController.dispose();
    super.dispose();
  }

  // =============================================
  // [3.3.2] BUILD
  // =============================================
  @override
  Widget build(BuildContext context) {
    // [1a] Lấy chiều cao bàn phím để sheet đẩy lên, tránh che ô nhập liệu
    final keyboardInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF2C2C2E),    // nền sheet
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      // [1a] Cộng keyboardInset vào bottom padding → sheet tự đẩy lên trên bàn phím
      padding: EdgeInsets.fromLTRB(20, 16, 20, 24 + keyboardInset),
      // [1a] SingleChildScrollView để scroll khi nội dung tràn (bàn phím mở)
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
          // ── Handle bar ──
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[600],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          // ── Hàng 1: Dropdown chọn loại lặp + Switch bật/tắt ──
          _buildRepeatTypeRow(),
          const SizedBox(height: 16),

          // ── Hàng 2: Từ [ngày bắt đầu] ──
          _buildBeginDateRow(),
          const SizedBox(height: 12),

          // ── Hàng 3: Mỗi [N] [đơn vị] ──
          _buildIntervalRow(),
          const SizedBox(height: 12),

          // ── Hàng 4: 7 ô tròn chọn ngày (chỉ khi weekly) ──
          if (_repeatType == RepeatType.weekly.value) ...[
            _buildWeekDaySelector(),
            const SizedBox(height: 12),
          ],

          // ── Hàng 5: Message mô tả (chỉ khi monthly) ──
          if (_repeatType == RepeatType.monthly.value) ...[
            _buildMonthlyDescription(),
            const SizedBox(height: 12),
          ],

          // ── Hàng 6: EndDateSelector ──
          _buildEndDateSelector(),
          const SizedBox(height: 20),

          // ── Hàng 7: Nút HUỶ + XONG ──
          _buildActionButtons(),
        ],
      ),   // end Column
    ),     // end SingleChildScrollView
    );     // end Container
  }

  // =============================================
  // [3.3.3] DROPDOWN LOẠI LẶP + SWITCH
  // =============================================
  Widget _buildRepeatTypeRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Dropdown chọn loại lặp
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF3A3A3C),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: _repeatType,
              dropdownColor: const Color(0xFF3A3A3C),
              style: const TextStyle(color: Colors.white, fontSize: 14),
              items: [
                // [TODO i18n] Repeat type labels
                DropdownMenuItem(value: RepeatType.daily.value, child: const Text('Daily')),
                DropdownMenuItem(value: RepeatType.weekly.value, child: const Text('Weekly')),
                DropdownMenuItem(value: RepeatType.monthly.value, child: const Text('Monthly')),
                DropdownMenuItem(value: RepeatType.yearly.value, child: const Text('Yearly')),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _repeatType = val);
              },
            ),
          ),
        ),

        // Switch bật/tắt — chỉ hiện khi đang sửa
        if (widget.isEditing)
          Switch(
            value: _isActive,
            activeTrackColor: const Color(0xFF4CAF50),
            onChanged: (val) {
              setState(() => _isActive = val);
            },
          ),
      ],
    );
  }

  // =============================================
  // [3.3.4] NGÀY BẮT ĐẦU
  // =============================================
  Widget _buildBeginDateRow() {
    // Hiển thị: "Hôm nay", "Ngày mai", hoặc dd/MM/yyyy
    String dateLabel;
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final tomorrow = today.add(const Duration(days: 1));
    final target = DateTime(_beginDate.year, _beginDate.month, _beginDate.day);

    // [TODO i18n] Date labels
    if (target == today) {
      dateLabel = 'Today';
    } else if (target == tomorrow) {
      dateLabel = 'Tomorrow';
    } else {
      dateLabel = DateFormat('dd/MM/yyyy').format(_beginDate);
    }

    return Row(
      children: [
        // [TODO i18n] Label 'From'
        const Text(
          'From',
          style: TextStyle(fontSize: 14, color: Color(0xFF8E8E93)),
        ),
        const SizedBox(width: 12),
        // ✅ [FIX-3a] Xóa GestureDetector → dùng Material + InkWell để responsive tốt hơn
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _pickBeginDate,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF3A3A3C),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    dateLabel,
                    style: const TextStyle(fontSize: 14, color: Colors.white),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.keyboard_arrow_down, size: 18, color: Color(0xFF8E8E93)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // =============================================
  // [3.3.5] KHOẢNG LẶP (MỖI N ĐƠN VỊ)
  // =============================================
  Widget _buildIntervalRow() {
    // Đơn vị tự đổi theo repeatType
    // [TODO i18n] Interval unit labels
    String unit;
    switch (_repeatType) {
      case 1: unit = 'day'; break;   // daily
      case 2: unit = 'week'; break;   // weekly
      case 3: unit = 'month'; break;  // monthly
      case 4: unit = 'year'; break;    // yearly
      default: unit = 'day';
    }

    return Row(
      children: [
        const Text(
          'Every',
          style: TextStyle(fontSize: 14, color: Color(0xFF8E8E93)),
        ),
        const SizedBox(width: 12),
        // Input số
        SizedBox(
          width: 60,
          child: TextField(
            controller: _intervalController,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: Colors.white),
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFF3A3A3C),
              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (val) {
              final parsed = int.tryParse(val);
              if (parsed != null && parsed > 0) {
                _interval = parsed;
              }
            },
          ),
        ),
        const SizedBox(width: 8),
        Text(
          unit,
          style: const TextStyle(fontSize: 14, color: Color(0xFF8E8E93)),
        ),
      ],
    );
  }

  // =============================================
  // [3.3.6] 7 Ô TRÒN CHỌN NGÀY (WEEKLY)
  // =============================================
  Widget _buildWeekDaySelector() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: List.generate(7, (index) {
        final bitmaskVal = _dayBitmaskValues[index]; // CN=1, T2=2, T3=4...
        final isSelected = FormatHelper.hasDay(_dayBitmask, bitmaskVal);

        return GestureDetector(
          onTap: () {
            setState(() {
              if (isSelected) {
                // Bỏ chọn — nhưng phải giữ ít nhất 1 ngày
                final afterRemove = FormatHelper.removeDay(_dayBitmask, bitmaskVal);
                if (afterRemove > 0) _dayBitmask = afterRemove;
              } else {
                // Thêm ngày
                _dayBitmask = FormatHelper.addDay(_dayBitmask, bitmaskVal);
              }
            });
          },
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSelected ? const Color(0xFF4CAF50) : Colors.transparent,
              border: Border.all(
                color: isSelected ? const Color(0xFF4CAF50) : const Color(0xFF4CAF50),
                width: 1.5,
              ),
            ),
            child: Center(
              child: Text(
                _dayLabels[index],
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : const Color(0xFF4CAF50),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  // =============================================
  // [3.3.7] MÔ TẢ LẶP HÀNG THÁNG
  // =============================================
  // Tính động theo beginDate và interval
  // VD: "Lặp vào ngày 14 hàng tháng" hoặc "Lặp vào ngày 14, mỗi 2 tháng một lần"
  Widget _buildMonthlyDescription() {
    final day = _beginDate.day;
    String desc;
    // [TODO i18n] Monthly description
    if (_interval == 1) {
      desc = 'Repeat on day $day every month';
    } else {
      desc = 'Repeat on day $day, every $_interval months';
    }
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        desc,
        style: const TextStyle(fontSize: 13, color: Color(0xFF8E8E93), fontStyle: FontStyle.italic),
      ),
    );
  }

  // =============================================
  // [3.3.8] END DATE SELECTOR (inline — không tách file)
  // =============================================
  Widget _buildEndDateSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Dropdown chọn kiểu kết thúc
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF3A3A3C),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _endDateOption,
              dropdownColor: const Color(0xFF3A3A3C),
              style: const TextStyle(color: Colors.white, fontSize: 14),
              isExpanded: true,
              items: const [
                // [TODO i18n] End date options
                DropdownMenuItem(value: 'FOREVER', child: Text('Forever')),
                DropdownMenuItem(value: 'UNTIL_DATE', child: Text('Until date')),
                DropdownMenuItem(value: 'COUNT', child: Text('Occurs ... times')),
              ],
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _endDateOption = val;
                    // Reset giá trị liên quan khi đổi option
                    if (val == 'UNTIL_DATE') {
                      // [FIX-3b] Đảm bảo endDateValue luôn > beginDate
                      if (_endDateValue == null || _endDateValue!.isBefore(_beginDate)) {
                        _endDateValue = _beginDate.add(const Duration(days: 30));
                      }
                    }
                    if (val == 'COUNT' && _repeatCount == null) {
                      _repeatCount = 1;
                      _countController.text = '1';
                    }
                  });
                }
              },
            ),
          ),
        ),
        const SizedBox(height: 8),

        // Nếu chọn "Cho đến ngày" → DatePicker
        if (_endDateOption == 'UNTIL_DATE')
          _buildUntilDateRow(),

        // Nếu chọn "Xảy ra ... lần" → TextField số
        if (_endDateOption == 'COUNT')
          _buildRepeatCountRow(),
      ],
    );
  }

  // ----- "Cho đến ngày [dd/MM/yyyy]" -----
  Widget _buildUntilDateRow() {
    // [TODO i18n] End date button label
    final label = _endDateValue != null
        ? DateFormat('dd/MM/yyyy').format(_endDateValue!)
        : 'Select date';

    return Row(
      children: [
        // [TODO i18n] 'Until date' label
        const Text(
          'Until date',
          style: TextStyle(fontSize: 14, color: Color(0xFF8E8E93)),
        ),
        const SizedBox(width: 12),
        // ✅ [FIX-3c] Dùng TextButton thay InkWell
        TextButton(
          onPressed: _pickEndDate,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            backgroundColor: const Color(0xFF3A3A3C),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            splashFactory: InkRipple.splashFactory,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 14, color: Colors.white),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.keyboard_arrow_down, size: 18, color: Color(0xFF8E8E93)),
            ],
          ),
        ),
      ],
    );
  }

  // ----- "Xảy ra [N] lần" -----
  Widget _buildRepeatCountRow() {
    return Row(
      children: [
        // [TODO i18n] 'Occurs' label for count option
        const Text(
          'Occur',
          style: TextStyle(fontSize: 14, color: Color(0xFF8E8E93)),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 60,
          child: TextField(
            controller: _countController,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: Colors.white),
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFF3A3A3C),
              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (val) {
              final parsed = int.tryParse(val);
              if (parsed != null && parsed > 0) {
                _repeatCount = parsed;
              }
            },
          ),
        ),
        const SizedBox(width: 8),
        // [TODO i18n] 'times' suffix
        const Text(
          'times',
          style: TextStyle(fontSize: 14, color: Color(0xFF8E8E93)),
        ),
      ],
    );
  }

  // =============================================
  // [3.3.9] NÚT HUỶ + XONG
  // =============================================
  Widget _buildActionButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        // Nút HUỶ — đóng sheet không trả gì
        TextButton(
          onPressed: () => Navigator.pop(context),
            // [TODO i18n] Cancel button
            child: const Text(
                'CANCEL',
                style: TextStyle(color: Color(0xFF8E8E93), fontWeight: FontWeight.w600),
              ),
        ),
        const SizedBox(width: 16),
        // Nút XONG — trả dữ liệu về Screen cha
        TextButton(
          onPressed: _handleConfirm,
            // [TODO i18n] Confirm button
            child: const Text(
                'DONE',
                style: TextStyle(color: Color(0xFF4CAF50), fontWeight: FontWeight.w600),
              ),
        ),
      ],
    );
  }

  // =============================================
  // [3.3.10] XỬ LÝ KHI BẤM XONG
  // =============================================
  void _handleConfirm() {
    // Bước 1: Đọc interval từ controller
    final parsedInterval = int.tryParse(_intervalController.text) ?? 1;
    final parsedCount = int.tryParse(_countController.text);

    // Bước 2: Nếu isEditing và switch đổi → gọi toggle callback
    if (widget.isEditing && _isActive != widget.isActive) {
      widget.onToggle?.call();
    }

    // Bước 3: Build result và trả về
    final result = RepeatScheduleResult(
      repeatType: _repeatType,
      repeatInterval: parsedInterval > 0 ? parsedInterval : 1,
      beginDate: _beginDate,
      repeatOnDayVal: _repeatType == RepeatType.weekly.value ? _dayBitmask : null,
      endDateOption: _endDateOption,
      endDateValue: _endDateOption == 'UNTIL_DATE' ? _endDateValue : null,
      repeatCount: _endDateOption == 'COUNT' ? (parsedCount ?? 1) : null,
    );

    widget.onConfirm(result);
    Navigator.pop(context);
  }

  // =============================================
  // [3.3.11] DATE PICKERS
  // =============================================

  // DatePicker cho ngày bắt đầu — chỉ cho chọn từ hôm nay trở đi (quá khứ bị xám)
  // Không đóng sheet trước — dialog xuất hiện trên cùng nhờ useRootNavigator: true
  Future<void> _pickBeginDate() async {
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final beginDateStripped = DateTime(_beginDate.year, _beginDate.month, _beginDate.day);
    final initialDate = beginDateStripped.isBefore(today) ? today : beginDateStripped;

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: today,      // Ngày trong quá khứ bị làm xám
      lastDate: today.add(const Duration(days: 365 * 5)),
      useRootNavigator: true, // Dialog nổi lên trên sheet — không cần pop sheet trước
      // [NOTE] Không dùng locale: Locale('vi','VN') vì cần GlobalMaterialLocalizations.delegate
    );

    if (!mounted) return;
    if (picked != null) setState(() => _beginDate = picked);
  }

  // DatePicker cho ngày kết thúc — chỉ cho chọn từ beginDate trở đi
  Future<void> _pickEndDate() async {
    final initialDate = (_endDateValue != null && _endDateValue!.isAfter(_beginDate))
        ? _endDateValue!
        : _beginDate.add(const Duration(days: 30));

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: _beginDate, // Không cho chọn trước ngày bắt đầu
      lastDate: _beginDate.add(const Duration(days: 365 * 10)),
      useRootNavigator: true,
      // [NOTE] Không dùng locale: Locale('vi','VN') vì cần GlobalMaterialLocalizations.delegate
    );

    if (!mounted) return;
    if (picked != null) setState(() => _endDateValue = picked);
  }
}

