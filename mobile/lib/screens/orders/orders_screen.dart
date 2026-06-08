import 'package:flutter/material.dart';
import '../../core/api_client.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  bool _isBuy = true;
  bool _isLimit = true;
  bool _loading = false;

  final _tickerCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController();

  @override
  void dispose() {
    _tickerCtrl.dispose();
    _priceCtrl.dispose();
    _qtyCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final ticker = _tickerCtrl.text.trim().toUpperCase();
    final qty = int.tryParse(_qtyCtrl.text.trim()) ?? 0;
    if (ticker.isEmpty || qty <= 0) {
      _showSnack('종목 코드와 수량을 올바르게 입력하세요', Colors.orange);
      return;
    }

    final type = _isLimit ? 'limit' : 'market';
    final side = _isBuy ? 'buy' : 'sell';
    final endpoint = '/api/v1/orders/$side/$type';

    final body = {
      'ticker': ticker,
      'quantity': qty,
      if (_isLimit) 'price': int.tryParse(_priceCtrl.text.trim()) ?? 0,
    };

    setState(() => _loading = true);
    try {
      await ApiClient.instance.post(endpoint, body);
      _showSnack('주문 완료!', Colors.green);
      _tickerCtrl.clear();
      _priceCtrl.clear();
      _qtyCtrl.clear();
    } catch (e) {
      _showSnack(e.toString(), Colors.red);
    } finally {
      setState(() => _loading = false);
    }
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('주문')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _BuySellToggle(isBuy: _isBuy, onChanged: (v) => setState(() => _isBuy = v)),
            const SizedBox(height: 16),
            _OrderTypeToggle(isLimit: _isLimit, onChanged: (v) => setState(() => _isLimit = v)),
            const SizedBox(height: 24),
            _FormField(
              controller: _tickerCtrl,
              label: '종목 코드',
              hint: '예: 005930',
              textCaps: true,
            ),
            const SizedBox(height: 12),
            if (_isLimit) ...[
              _FormField(
                controller: _priceCtrl,
                label: '주문 가격 (원)',
                hint: '예: 75000',
                isNumber: true,
              ),
              const SizedBox(height: 12),
            ],
            _FormField(
              controller: _qtyCtrl,
              label: '주문 수량 (주)',
              hint: '예: 1',
              isNumber: true,
            ),
            const SizedBox(height: 32),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _loading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isBuy ? Colors.red : Colors.blue,
                  foregroundColor: Colors.white,
                ),
                child: _loading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(
                        '${_isBuy ? '매수' : '매도'} ${_isLimit ? '지정가' : '시장가'} 주문',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BuySellToggle extends StatelessWidget {
  final bool isBuy;
  final ValueChanged<bool> onChanged;
  const _BuySellToggle({required this.isBuy, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ToggleBtn(
            label: '매수',
            selected: isBuy,
            selectedColor: Colors.red,
            onTap: () => onChanged(true),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _ToggleBtn(
            label: '매도',
            selected: !isBuy,
            selectedColor: Colors.blue,
            onTap: () => onChanged(false),
          ),
        ),
      ],
    );
  }
}

class _OrderTypeToggle extends StatelessWidget {
  final bool isLimit;
  final ValueChanged<bool> onChanged;
  const _OrderTypeToggle({required this.isLimit, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ToggleBtn(
            label: '지정가',
            selected: isLimit,
            selectedColor: Colors.orange,
            onTap: () => onChanged(true),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _ToggleBtn(
            label: '시장가',
            selected: !isLimit,
            selectedColor: Colors.orange,
            onTap: () => onChanged(false),
          ),
        ),
      ],
    );
  }
}

class _ToggleBtn extends StatelessWidget {
  final String label;
  final bool selected;
  final Color selectedColor;
  final VoidCallback onTap;
  const _ToggleBtn({required this.label, required this.selected, required this.selectedColor, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? selectedColor.withValues(alpha:0.15) : Colors.transparent,
          border: Border.all(color: selected ? selectedColor : Colors.grey.withValues(alpha:0.3)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: selected ? selectedColor : Colors.grey,
          ),
        ),
      ),
    );
  }
}

class _FormField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final bool isNumber;
  final bool textCaps;
  const _FormField({
    required this.controller,
    required this.label,
    required this.hint,
    this.isNumber = false,
    this.textCaps = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
      ),
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      textCapitalization: textCaps ? TextCapitalization.characters : TextCapitalization.none,
    );
  }
}
