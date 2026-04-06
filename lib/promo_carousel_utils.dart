/// Helpers for promo [PageView]s so auto-advance always moves **forward** to the
/// next page. Content uses `index % itemCount` — avoids `animateToPage(0)` from the
/// last slide, which scrolls **backward** through all pages.

const int kPromoVirtualPageCount = 200000;

int promoVirtualBasePage(int itemCount) {
  if (itemCount <= 0) return 0;
  const mid = 100000;
  return mid - (mid % itemCount);
}
