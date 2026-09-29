import gleeunit/should
import nexus_agency/permissions

pub fn admin_and_owner_can_manage_test() {
  permissions.is_admin_or_owner("admin") |> should.be_true
  permissions.is_admin_or_owner("owner") |> should.be_true
  permissions.is_admin_or_owner("staff") |> should.be_false
}

pub fn role_permission_matrix_test() {
  permissions.can("supplier", "catalog.write") |> should.be_true
  permissions.can("supplier", "sync.manage") |> should.be_false
  permissions.can("staff", "reports.read") |> should.be_true
  permissions.can("sub_agency", "catalog.write") |> should.be_false
  permissions.can("customer", "booking.create") |> should.be_true
}

