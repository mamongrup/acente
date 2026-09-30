import gleam/io
import gleam/list
import gleeunit/should
import nexus_agency/parampos

pub fn main() {
  successful_payment_test()
  incomplete_and_failed_payment_test()
  namespaced_cdata_and_entities_test()
  entity_declarations_rejected_test()
  three_d_status_test()
  callback_hash_fixture_test()
  refund_response_requires_bank_proof_test()
  refund_amount_format_test()
  io.println("8 ParamPOS protocol tests passed.")
}

pub fn refund_response_requires_bank_proof_test() {
  parampos.parse_refund(
    "<r><Sonuc>1</Sonuc><Sonuc_Str>Approved</Sonuc_Str><Banka_Sonuc_Kod>0</Banka_Sonuc_Kod><Bank_Trans_ID>TX-123</Bank_Trans_ID></r>",
  )
  |> parampos.refund_success
  |> should.be_true
  [
    "<r><Sonuc>1</Sonuc><Banka_Sonuc_Kod>0</Banka_Sonuc_Kod></r>",
    "<r><Sonuc>1</Sonuc><Banka_Sonuc_Kod>5</Banka_Sonuc_Kod><Bank_Trans_ID>TX-123</Bank_Trans_ID></r>",
    "<r><Sonuc>-1</Sonuc><Banka_Sonuc_Kod>0</Banka_Sonuc_Kod><Bank_Trans_ID>TX-123</Bank_Trans_ID></r>",
  ]
  |> list.each(fn(xml) {
    parampos.parse_refund(xml) |> parampos.refund_success |> should.be_false
  })
}

pub fn refund_amount_format_test() {
  parampos.amount_minor_to_parampos(37_035) |> should.equal(Ok("370.35"))
  parampos.amount_minor_to_parampos(101) |> should.equal(Ok("1.01"))
  parampos.amount_minor_to_parampos(0) |> should.be_error
}

pub fn successful_payment_test() {
  parampos.parse_pay(
    "<TP_WMD_PayResult><Sonuc>1</Sonuc><Dekont_ID>12345</Dekont_ID><Bank_Sonuc_Kod>0</Bank_Sonuc_Kod></TP_WMD_PayResult>",
  )
  |> parampos.pay_success
  |> should.be_true
}

pub fn incomplete_and_failed_payment_test() {
  [
    "",
    "<broken",
    "<r><Sonuc>1</Sonuc><Dekont_ID>123</Dekont_ID></r>",
    "<r><Sonuc>1</Sonuc><Dekont_ID>0</Dekont_ID><Bank_Sonuc_Kod>0</Bank_Sonuc_Kod></r>",
    "<r><Sonuc>1</Sonuc><Dekont_ID>123</Dekont_ID><Bank_Sonuc_Kod>5</Bank_Sonuc_Kod></r>",
    "<r><Sonuc>-1</Sonuc><Dekont_ID>123</Dekont_ID><Bank_Sonuc_Kod>0</Bank_Sonuc_Kod></r>",
  ]
  |> list.each(fn(xml) {
    parampos.parse_pay(xml) |> parampos.pay_success |> should.be_false
  })
}

pub fn namespaced_cdata_and_entities_test() {
  let p =
    parampos.parse_pay(
      "<s:r xmlns:s='urn:test'><s:Sonuc>1</s:Sonuc><s:Sonuc_Ack><![CDATA[OK & done]]></s:Sonuc_Ack><s:Dekont_ID>&#49;23</s:Dekont_ID><s:Banka_Sonuc_Kod>0</s:Banka_Sonuc_Kod></s:r>",
    )
  p.message |> should.equal("OK & done")
  p |> parampos.pay_success |> should.be_true
}

pub fn entity_declarations_rejected_test() {
  parampos.parse_pay(
    "<!DOCTYPE r [<!ENTITY x '1'>]><r><Sonuc>&x;</Sonuc><Dekont_ID>123</Dekont_ID><Bank_Sonuc_Kod>0</Bank_Sonuc_Kod></r>",
  )
  |> parampos.pay_success
  |> should.be_false
}

pub fn three_d_status_test() {
  ["1", "2", "3", "4"]
  |> list.each(fn(s) { parampos.md_success(s) |> should.be_true })
  ["0", "5", "6", "7", "8", "", "01"]
  |> list.each(fn(s) { parampos.md_success(s) |> should.be_false })
}

pub fn callback_hash_fixture_test() {
  parampos.callback_hash("ABC", "txn", "md", "1", "order")
  |> should.equal("gKV3Ku61AnSZJIlelWw/xN+a++o=")
}
