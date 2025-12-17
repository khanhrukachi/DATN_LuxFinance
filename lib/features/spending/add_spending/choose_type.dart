import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';
import 'package:personal_financial_management/core/constants/app_styles.dart';
import 'package:personal_financial_management/core/constants/list.dart';
import 'package:personal_financial_management/setting/localization/app_localizations.dart';

class ChooseType extends StatefulWidget {
  const ChooseType({Key? key, required this.action}) : super(key: key);
  final Function(int index, int coefficient, String? name) action;

  @override
  State<ChooseType> createState() => _ChooseTypeState();
}

class _ChooseTypeState extends State<ChooseType> with TickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _typeController = TextEditingController();
  final _name = TextEditingController();
  List<String> title = ["all", "spending", "income"];
  String selectedValue = "all";

  @override
  void initState() {
    _tabController = TabController(length: 2, vsync: this);
    _typeController.addListener(() => setState(() {}));
    super.initState();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _typeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.background,
        elevation: 0,
        centerTitle: true,
        title: DropdownButtonHideUnderline(
          child: DropdownButton2<String>(
            customButton: SizedBox(
              width: 140,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    AppLocalizations.of(context).translate(selectedValue),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Icon(Icons.arrow_drop_down),
                ],
              ),
            ),
            value: selectedValue,
            items: title
                .map(
                  (item) => DropdownMenuItem<String>(
                value: item,
                child: Text(
                  AppLocalizations.of(context).translate(item),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            )
                .toList(),
            onChanged: (value) {
              setState(() {
                selectedValue = value!;
              });
            },
            dropdownStyleData: DropdownStyleData(
              maxHeight: 200,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            buttonStyleData: ButtonStyleData(
              height: 40,
              width: 140,
            ),
            menuItemStyleData: const MenuItemStyleData(
              height: 40,
            ),
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(65),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
            child: TextFormField(
              controller: _typeController,
              style: const TextStyle(fontSize: 16),
              decoration: InputDecoration(
                filled: true,
                fillColor: Theme.of(context).scaffoldBackgroundColor,
                border: InputBorder.none,
                hintText: AppLocalizations.of(context).translate("search"),
                hintStyle: const TextStyle(fontSize: 16),
                contentPadding: const EdgeInsets.all(10),
                focusedBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: Colors.white),
                  borderRadius: BorderRadius.circular(15),
                ),
                enabledBorder: UnderlineInputBorder(
                  borderSide: const BorderSide(color: Colors.white),
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
            ),
          ),
        ),
      ),
      body: ListView.builder(
        itemCount: listType.length,
        itemBuilder: (context, index) {
          int choose = title.indexOf(selectedValue);
          bool checkSearch = AppLocalizations.of(context)
              .translate(listType[index]["title"]!)
              .toLowerCase()
              .contains(_typeController.text.toLowerCase());
          if ((checkSearch) &&
              (choose == 0 ||
                  choose == 2 &&
                      [29, 30, 34, 36, 37, 40, 27, 35, 38, 41]
                          .contains(index) ||
                  choose == 1 &&
                      ![29, 30, 34, 36, 37, 40, 35].contains(index))) {
            if ([0, 10, 21, 27, 35, 38].contains(index)) {
              return Padding(
                padding: const EdgeInsets.only(top: 20, bottom: 10, left: 15),
                child: Text(
                  AppLocalizations.of(context)
                      .translate(listType[index]["title"]!),
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              );
            }

            return InkWell(
              onTap: () async {
                if (index != 41) {
                  widget.action(
                      index, _tabController.index == 0 ? -1 : 1, null);
                  Navigator.pop(context);
                } else {
                  await showNewType();
                  _name.text = "";
                }
              },
              child: Material(
                elevation: 2,
                child: Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                  height: 60,
                  width: double.infinity,
                  child: Row(
                    children: [
                      Image.asset(
                        listType[index]["image"]!,
                        width: 40,
                      ),
                      const SizedBox(width: 15),
                      Text(
                        AppLocalizations.of(context)
                            .translate(listType[index]["title"]!),
                        style: AppStyles.p,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }

  Future showNewType() async {
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Center(
            child: Text(AppLocalizations.of(context).translate('new_type')),
          ),
          content: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _name,
                  maxLines: 10,
                  minLines: 1,
                  style: AppStyles.p,
                  textCapitalization: TextCapitalization.sentences,
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.multiline,
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText:
                    AppLocalizations.of(context).translate('type_name'),
                    hintStyle: AppStyles.p,
                  ),
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: () {
                    widget.action(
                        41, _tabController.index == 0 ? -1 : 1, _name.text);
                    Navigator.pop(context);
                    Navigator.pop(context);
                  },
                  child: const Text("OK"),
                )
              ],
            ),
          ),
        );
      },
    );
  }
}
