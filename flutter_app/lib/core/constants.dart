/// Konstanta bisnis — HARUS sama dengan backend (`backend/server.py`).
library;

/// Minimal penarikan saldo kreator (`MIN_WITHDRAW`).
const int kMinWithdraw = 50000;

/// Minimal top up saldo brand (`TopupIn.amount ge=10000`).
const int kMinTopup = 10000;

/// Minimal budget campaign (`CampaignIn.budget ge=100000`).
const int kMinCampaignBudget = 100000;

/// Kategori campaign yang valid (`CATEGORIES`).
const List<String> kCategories = [
  'Produk',
  'Beauty',
  'Lifestyle',
  'F&B',
  'Edukasi',
  'Hiburan',
  'Fashion',
  'Tech',
];

/// Kanal Virtual Account yang ditawarkan untuk top up bank transfer.
const List<String> kVaChannels = ['BCA', 'BNI', 'BRI', 'MANDIRI', 'PERMATA', 'CIMB'];

/// Nominal cepat di halaman top up.
const List<int> kTopupPresets = [100000, 250000, 500000, 1000000];

/// Metode penarikan saldo kreator (bank & e-wallet).
const List<String> kWithdrawMethods = ['BCA', 'BNI', 'BRI', 'Mandiri', 'DANA', 'OVO', 'GoPay', 'ShopeePay'];

/// Interval cek otomatis status top up selama masih pending
/// (Komerce membatasi maks. 1 request / 3 detik).
const Duration kTopupPollInterval = Duration(seconds: 5);
