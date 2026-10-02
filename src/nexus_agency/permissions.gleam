/// Merkezi panel/işlem yetkileri.
///
/// Tenant ve kullanıcı kapsamı auth.Session içinde doğrulanır; bu modül
/// route'ların aynı karar kurallarını kullanmasını sağlar.
pub fn is_admin_or_owner(membership: String) -> Bool {
  membership == "admin" || membership == "owner"
}

pub fn can(membership: String, permission: String) -> Bool {
  case membership {
    "admin" | "owner" -> True
    "supplier" ->
      permission == "dashboard.read"
      || permission == "catalog.read"
      || permission == "catalog.write"
      || permission == "campaigns.supplier"
    "staff" ->
      permission == "dashboard.read"
      || permission == "catalog.read"
      || permission == "catalog.write"
      || permission == "reservations.read"
      || permission == "reservations.write"
      || permission == "customers.read"
      || permission == "customers.write"
      || permission == "inquiries.read"
      || permission == "inquiries.write"
      || permission == "reports.read"
    "sub_agency" ->
      permission == "dashboard.read"
      || permission == "catalog.read"
      || permission == "reservations.read"
      || permission == "reservations.write"
      || permission == "customers.read"
      || permission == "customers.write"
      || permission == "inquiries.read"
    _ ->
      permission == "storefront.read"
      || permission == "booking.create"
      || permission == "inquiries.create"
  }
}
