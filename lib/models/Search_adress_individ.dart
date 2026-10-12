import 'dart:async';
import 'package:flutter/material.dart';

import '../../Api_Servicess.dart';

class IndividualAddressScreen extends StatefulWidget {
  const IndividualAddressScreen({super.key});

  @override
  State<IndividualAddressScreen> createState() => _IndividualAddressScreenState();
}

class _IndividualAddressScreenState extends State<IndividualAddressScreen> {
  // --- Контроллеры ---
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();

  // --- Состояния города ---
  List<Map<String, dynamic>> _townSuggestions = [];
  bool _isLoadingTowns = false;
  Map<String, dynamic>? _selectedTown;

  // --- Состояния адреса ---
  List<Map<String, dynamic>> _addressSuggestions = [];
  bool _isLoadingAddresses = false;
  Map<String, dynamic>? _selectedAddress;

  // Таймеры для задержки запросов (дебаунс)
  Timer? _townDebounce;
  Timer? _addressDebounce;

  @override
  void dispose() {
    _cityController.dispose();
    _addressController.dispose();
    _townDebounce?.cancel();
    _addressDebounce?.cancel();
    super.dispose();
  }

  // ================= ПОИСК ГОРОДА =================
  void _onCityChanged(String query) {
    _townDebounce?.cancel();

    if (query.trim().isEmpty) {
      setState(() {
        _townSuggestions = [];
        _selectedTown = null;
        _isLoadingTowns = false;
        _resetAddressState();
      });
      return;
    }

    _townDebounce = Timer(const Duration(milliseconds: 300), () async {
      setState(() => _isLoadingTowns = true);

      final results = await AddressApiService.searchTown(query);

      if (mounted) {
        setState(() {
          _townSuggestions = results;
          _isLoadingTowns = false;
        });
      }
    });
  }

  void _selectTown(Map<String, dynamic> town) {
    setState(() {
      _selectedTown = town;
      _cityController.text = town['name'] ?? '';
      _townSuggestions = []; // Закрываем подсказки городов
      _resetAddressState(); // Очищаем старый выбранный адрес при смене города
    });
  }

  // ================= ПОИСК АДРЕСА =================
  void _onAddressChanged(String query) {
    _addressDebounce?.cancel();

    if (_selectedTown == null) return;

    if (query.trim().isEmpty) {
      setState(() {
        _addressSuggestions = [];
        _selectedAddress = null;
        _isLoadingAddresses = false;
      });
      return;
    }

    _addressDebounce = Timer(const Duration(milliseconds: 300), () async {
      setState(() => _isLoadingAddresses = true);

      final int townId = _selectedTown!['id'] is int
          ? _selectedTown!['id']
          : int.parse(_selectedTown!['id'].toString());

      final results = await AddressApiService.searchAddress(query, townId);

      if (mounted) {
        setState(() {
          _addressSuggestions = results;
          _isLoadingAddresses = false;
        });
      }
    });
  }

  // Выбор пункта из выпадающего списка адресов
  void _selectAddress(Map<String, dynamic> address) async {
    final String selectedName = address['name'] ?? address['street'] ?? '';

    // Если вариант содержит конкретный номер дома
    if (_hasHouseNumber(selectedName)) {
      setState(() {
        _addressController.text = selectedName;
        _addressSuggestions = []; // Закрываем список
        _isLoadingAddresses = true;
      });
      FocusScope.of(context).unfocus();

      final int townId = _selectedTown!['id'] is int
          ? _selectedTown!['id']
          : int.parse(_selectedTown!['id'].toString());

      // Получаем детальные данные с координатами и ID через /v1/checkAddress
      final fullAddressData = await AddressApiService.checkAddress(selectedName, townId);

      if (mounted) {
        setState(() {
          _isLoadingAddresses = false;
          _selectedAddress = fullAddressData ?? address;
        });
      }
    } else {
      // Если выбрана только улица без номера — добавляем пробел и перезапрашиваем дома
      final String queryWithSpace = '$selectedName ';
      _addressController.text = queryWithSpace;
      _addressController.selection = TextSelection.fromPosition(
        TextPosition(offset: queryWithSpace.length),
      );

      _onAddressChanged(queryWithSpace);
    }
  }

  bool _hasHouseNumber(String text) {
    return RegExp(r'\d').hasMatch(text);
  }

  void _resetAddressState() {
    _addressController.clear();
    _addressSuggestions = [];
    _selectedAddress = null;
    _isLoadingAddresses = false;
  }

  // Подтверждение выбора и передача данных назад
  void _confirmAndReturn() {
    if (_selectedAddress == null) return;

    final Map<String, dynamic> returnData = Map<String, dynamic>.from(_selectedAddress!);
    returnData['town'] = _selectedTown?['name'] ?? '';

    Navigator.pop(context, returnData);
  }

  // ================= UI СБОРКА =================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F7),
      appBar: AppBar(
        title: const Text(
          'Укажите адрес',
          style: TextStyle(
            color: Color(0xFF111111),
            fontWeight: FontWeight.w800,
            fontSize: 17,
            letterSpacing: -0.3,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Color(0xFF111111)),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- ЕДИНЫЙ БЛОК ВВОДА ---
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // --- ПОЛЕ 1: ПОИСК ГОРОДА ---
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                            child: Row(
                              children: [
                                const Icon(Icons.location_city_rounded, color: Color(0xFF6B7280), size: 20),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextField(
                                    controller: _cityController,
                                    onChanged: _onCityChanged,
                                    style: const TextStyle(
                                      color: Color(0xFF111111),
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                    ),
                                    decoration: const InputDecoration(
                                      hintText: 'Город',
                                      hintStyle: TextStyle(color: Color(0xFF9CA3AF), fontWeight: FontWeight.w500),
                                      border: InputBorder.none,
                                      isDense: true,
                                      contentPadding: EdgeInsets.symmetric(vertical: 12),
                                    ),
                                  ),
                                ),
                                if (_isLoadingTowns)
                                  const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF111111)),
                                  )
                                else if (_cityController.text.isNotEmpty)
                                  InkWell(
                                    onTap: () {
                                      _cityController.clear();
                                      _onCityChanged('');
                                    },
                                    child: const Icon(Icons.close_rounded, color: Color(0xFF9CA3AF), size: 18),
                                  ),
                              ],
                            ),
                          ),

                          const Divider(height: 1, thickness: 1, color: Color(0xFFF3F4F6)),

                          // --- ПОЛЕ 2: ПОИСК АДРЕСА ---
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                            child: Row(
                              children: [
                                const Icon(Icons.search_rounded, color: Color(0xFF6B7280), size: 20),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextField(
                                    controller: _addressController,
                                    enabled: _selectedTown != null,
                                    onChanged: _onAddressChanged,
                                    style: const TextStyle(
                                      color: Color(0xFF111111),
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: _selectedTown != null ? 'Улица, дом' : 'Сначала выберите город',
                                      hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontWeight: FontWeight.w500),
                                      border: InputBorder.none,
                                      isDense: true,
                                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                                    ),
                                  ),
                                ),
                                if (_isLoadingAddresses)
                                  const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF111111)),
                                  )
                                else if (_addressController.text.isNotEmpty)
                                  InkWell(
                                    onTap: () {
                                      _addressController.clear();
                                      _onAddressChanged('');
                                    },
                                    child: const Icon(Icons.close_rounded, color: Color(0xFF9CA3AF), size: 18),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Выпадающий список подсказок для города
                    if (_townSuggestions.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        constraints: const BoxConstraints(maxHeight: 200),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
                          ],
                        ),
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: _townSuggestions.length,
                          separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF3F4F6)),
                          itemBuilder: (context, index) {
                            final town = _townSuggestions[index];
                            return ListTile(
                              title: Text(
                                town['name'] ?? '',
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF111111)),
                              ),
                              leading: const Icon(Icons.location_city_rounded, color: Color(0xFF6B7280), size: 18),
                              onTap: () => _selectTown(town),
                            );
                          },
                        ),
                      ),
                    ],

                    const SizedBox(height: 12),

                    // --- ЕДИНЫЙ СПИСОК РЕЗУЛЬТАТОВ И БЛИЖАЙШИХ АДРЕСОВ ---
                    if (_addressSuggestions.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 6.0),
                        child: Text(
                          'Результат поиска: ${_addressSuggestions.length}',
                          style: const TextStyle(
                            color: Color(0xFF6B7280),
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
                          ],
                        ),
                        child: ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _addressSuggestions.length,
                          separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF3F4F6)),
                          itemBuilder: (context, index) {
                            final item = _addressSuggestions[index];
                            final String addressName = item['name'] ?? item['street'] ?? '';

                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                              leading: const Icon(Icons.location_on_outlined, color: Color(0xFF6B7280), size: 18),
                              title: Text(
                                addressName,
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF111111)),
                              ),
                              onTap: () => _selectAddress(item),
                            );
                          },
                        ),
                      ),

                      const SizedBox(height: 16),

                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4.0, vertical: 6.0),
                        child: Text(
                          'Ближайшие адреса',
                          style: TextStyle(
                            color: Color(0xFF6B7280),
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
                          ],
                        ),
                        child: ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _addressSuggestions.length > 3 ? 3 : _addressSuggestions.length,
                          separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF3F4F6)),
                          itemBuilder: (context, index) {
                            final item = _addressSuggestions[index];
                            final String addressName = item['name'] ?? item['street'] ?? '';

                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                              leading: const Icon(Icons.near_me_outlined, color: Color(0xFF2563EB), size: 18),
                              title: Text(
                                addressName,
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF111111)),
                              ),
                              subtitle: const Text(
                                'Рядом с выбранным местом',
                                style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
                              ),
                              onTap: () => _selectAddress(item),
                            );
                          },
                        ),
                      ),
                    ],

                    // Информационный блок с выбранным адресом
                    if (_selectedAddress != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFF111111), width: 1.5),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'Выбранный адрес',
                                  style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF111111), fontSize: 14),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${_selectedTown!['name']}, ${_selectedAddress!['name'] ?? _selectedAddress!['street']}',
                              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF111111)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // --- КНОПКА ПОДТВЕРЖДЕНИЯ ---
            if (_selectedAddress != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 15,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _confirmAndReturn,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF111111),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Подтвердить адрес',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}