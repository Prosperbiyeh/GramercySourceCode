use [FHEG]

declare	@load_start_dt	datetime
declare @load_end_dt	datetime
declare @rows			int

set @load_start_dt = GETDATE()


begin transaction 

delete from FHEG.dbo.fh_policy
delete from FHEG.dbo.fh_policy_coverage
delete from FHEG.dbo.fh_claim
delete from FHEG.dbo.fh_claim_history
delete from FHEG.dbo.fh_claim_accident
delete from FHEG.dbo.fh_party
delete from FHEG.dbo.fh_party_history
delete from FHEG.dbo.fh_party_status
delete from FHEG.dbo.fh_payable
delete from FHEG.dbo.fh_reserve_paid
delete from FHEG.dbo.fh_lawsuit
delete from FHEG.dbo.fh_reserve_type
delete from FHEG.dbo.fh_company
delete from FHEG.dbo.fh_code_client
delete from FHEG.dbo.fh_code_general
delete from FHEG.dbo.fh_user
delete from FHEG.dbo.fh_lob
delete from FHEG.dbo.fh_lookup

insert into [FHEG].[dbo].[fh_policy]
select *
from [GRAMERCYFHE].[FEGramercy].[dbo].fh_policy
where tier1_company_id = 'C13339'




insert into [FHEG].[dbo].[fh_policy_coverage]
select c.*
from [GRAMERCYFHE].[FEGramercy].[dbo].fh_policy a,
     [GRAMERCYFHE].[FEGramercy].[dbo].fh_policy_coverage c
where a.tier1_company_id = 'C13339'
  and a.policy_id = c.policy_id





insert into [FHEG].[dbo].[fh_claim]
select b.*
from [GRAMERCYFHE].[FEGramercy].[dbo].fh_policy a,
     [GRAMERCYFHE].[FEGramercy].[dbo].fh_claim b
where a.tier1_company_id = 'C13339'
  and a.policy_id = b.policy_id



insert into [FHEG].[dbo].[fh_claim_history]
select c.*
from [GRAMERCYFHE].[FEGramercy].[dbo].fh_policy a,
     [GRAMERCYFHE].[FEGramercy].[dbo].fh_claim b,
     [GRAMERCYFHE].[FEGramercy].[dbo].fh_claim_history c
where a.tier1_company_id = 'C13339'
  and a.policy_id = b.policy_id
  and b.claim_id = c.claim_id




insert into [FHEG].[dbo].[fh_claim_accident]
select c.*
from [GRAMERCYFHE].[FEGramercy].[dbo].fh_policy a,
     [GRAMERCYFHE].[FEGramercy].[dbo].fh_claim b,
     [GRAMERCYFHE].[FEGramercy].[dbo].fh_claim_accident c
where a.tier1_company_id = 'C13339'
  and a.policy_id = b.policy_id
  and b.claim_id = c.claim_id





insert into [FHEG].[dbo].[fh_party]
select c.*
from [GRAMERCYFHE].[FEGramercy].[dbo].fh_policy a,
     [GRAMERCYFHE].[FEGramercy].[dbo].fh_claim b,
     [GRAMERCYFHE].[FEGramercy].[dbo].fh_party c
where a.tier1_company_id = 'C13339'
  and a.policy_id = b.policy_id
  and b.claim_id = c.claim_id





insert into [FHEG].[dbo].[fh_party_history]
select d.*
from [GRAMERCYFHE].[FEGramercy].[dbo].fh_policy a,
     [GRAMERCYFHE].[FEGramercy].[dbo].fh_claim b,
     [GRAMERCYFHE].[FEGramercy].[dbo].fh_party c,
	 [GRAMERCYFHE].[FEGramercy].[dbo].fh_party_history d
where a.tier1_company_id = 'C13339'
  and a.policy_id = b.policy_id
  and b.claim_id = c.claim_id
  and c.party_id = d.party_id




insert into [FHEG].[dbo].[fh_party_status]
select d.*
from [GRAMERCYFHE].[FEGramercy].[dbo].fh_policy a,
     [GRAMERCYFHE].[FEGramercy].[dbo].fh_claim b,
     [GRAMERCYFHE].[FEGramercy].[dbo].fh_party c,
	 [GRAMERCYFHE].[FEGramercy].[dbo].fh_party_status d
where a.tier1_company_id = 'C13339'
  and a.policy_id = b.policy_id
  and b.claim_id = c.claim_id
  and c.party_id = d.party_id




insert into [FHEG].[dbo].[fh_payable]
select d.*
from [GRAMERCYFHE].[FEGramercy].[dbo].fh_policy a,
     [GRAMERCYFHE].[FEGramercy].[dbo].fh_claim b,
     [GRAMERCYFHE].[FEGramercy].[dbo].fh_party c,
	 [GRAMERCYFHE].[FEGramercy].[dbo].fh_payable d
where a.tier1_company_id = 'C13339'
  and a.policy_id = b.policy_id
  and b.claim_id = c.claim_id
  and c.party_id = d.party_id




insert into [FHEG].[dbo].[fh_reserve_paid]
select d.*
from [GRAMERCYFHE].[FEGramercy].[dbo].fh_policy a,
     [GRAMERCYFHE].[FEGramercy].[dbo].fh_claim b,
     [GRAMERCYFHE].[FEGramercy].[dbo].fh_party c,
	 [GRAMERCYFHE].[FEGramercy].[dbo].fh_reserve_paid d
where a.tier1_company_id = 'C13339'
  and a.policy_id = b.policy_id
  and b.claim_id = c.claim_id
  and c.party_id = d.party_id

set @rows = @@ROWCOUNT


/*  MH  - 12/01/2022 - To adjust $350,000 reserve that was deleted from
               FHEG by Certus on 11/18/2022 back to its original date */

update [FHEG].[dbo].[fh_reserve_paid]
set added_date = '2020-06-24 12:57:03.703',
    reserve_date = '2020-06-24 12:56:46.000',
	reserve_description = 'New Reserve',
	reserve_type_code = 'NEW'
where reserve_paid_id = '000250000346512'




insert into [FHEG].[dbo].[fh_lawsuit]
select d.*
from [GRAMERCYFHE].[FEGramercy].[dbo].fh_policy a,
     [GRAMERCYFHE].[FEGramercy].[dbo].fh_claim b,
     [GRAMERCYFHE].[FEGramercy].[dbo].fh_party c,
	 [GRAMERCYFHE].[FEGramercy].[dbo].fh_lawsuit d
where a.tier1_company_id = 'C13339'
  and a.policy_id = b.policy_id
  and b.claim_id = c.claim_id
  and c.party_id = d.party_id




insert into [FHEG].[dbo].[fh_reserve_type]
select d.*
from [GRAMERCYFHE].[FEGramercy].[dbo].fh_reserve_type d




insert into [FHEG].[dbo].[fh_company]
select d.company_id,
		d.company_code,
		d.company_group,
		d.tier_type,
		d.company_name,
		d.tier1_company_id,
		d.tier2_company_id,
		d.tier3_company_id,
		d.tier4_company_id,
		d.tier5_company_id,
		d.tier6_company_id,
		d.tier1_name,
		d.tier2_name,
		d.tier3_name,
		d.tier4_name,
		d.tier5_name,
		d.tier6_name,
		d.address1,
		d.address2,
		d.city,
		d.state,
		d.zip_code,
		d.county,
		d.federal_id,
		d.phone1,
		d.phone2,
		d.fax,
		d.checking_account_id,
		d.next_claim_num,
		d.handler_hourly_rate,
		d.clerical_hourly_rate,
		d.mileage_rate,
		d.photograph_rate,
		d.photocopy_rate,
		d.handler_office_percent,
		d.clerical_office_percent,
		d.flat_rate_office_percent,
		d.expense_office_percent,
		d.replication_flag,
		d.on_notice_pct,
		d.billing_service_id,
		d.quantity_num,
		d.rate_amt,
		d.office_pct,
		d.global_tier_yn,
		d.tpa_insured_flag,
		d.dba_name,
		d.cross_reference_num,
		d.email_address,
		d.self_insured_yn,
		d.employer_tier_level,
		d.location_tier_level,
		d.industry_code,
		d.location_number,
		d.ui_number,
		d.pmsi_checking_account,
		d.pmsi_charge_res_type_id,
		d.pmsi_charge_pay_type_id,
		d.pmsi_charge_loss_or_alae,
		d.pmsi_fee_res_type_id,
		d.pmsi_fee_pay_type_id,
		d.pmsi_fee_loss_or_alae,
		d.pmsi_pay_cat_code,
		d.pmsi_exclude_yn,
		d.ccsbr_exclude_yn,
		d.ccsbr_checking_account,
		d.ccsbr_charge_pay_type_id,
		d.ccsbr_charge_res_type_id,
		d.ccsbr_charge_loss_or_alae,
		d.ccsbr_fee_pay_type_id,
		d.ccsbr_fee_res_type_id,
		d.ccsbr_fee_loss_or_alae,
		d.ccsbr_pay_cat_code,
		d.specific_schedule_codes_yn,
		d.analytic_export_yn,
		d.analytic_amount,
		d.analytic_bill_to,
		d.analytic_bill_service,
		d.analytic_bill_charge,
		d.analytic_medical_days,
		d.analytic_diary_handler,
		d.analytic_diary_priority,
		d.analytic_fee_type,
		d.analytic_payee_fed_id,
		d.analytic_payment_type,
		d.analytic_reserve_type,
		d.analytic_financial_type,
		d.certificate_tier_level,
		d.rmis_loc_tier_level
from [GRAMERCYFHE].[FEGramercy].[dbo].fh_policy a,
	 [GRAMERCYFHE].[FEGramercy].[dbo].fh_company d
where a.tier1_company_id = 'C13339'
  and a.tier_company_id = d.company_id
group by d.company_id,
		d.company_code,
		d.company_group,
		d.tier_type,
		d.company_name,
		d.tier1_company_id,
		d.tier2_company_id,
		d.tier3_company_id,
		d.tier4_company_id,
		d.tier5_company_id,
		d.tier6_company_id,
		d.tier1_name,
		d.tier2_name,
		d.tier3_name,
		d.tier4_name,
		d.tier5_name,
		d.tier6_name,
		d.address1,
		d.address2,
		d.city,
		d.state,
		d.zip_code,
		d.county,
		d.federal_id,
		d.phone1,
		d.phone2,
		d.fax,
		d.checking_account_id,
		d.next_claim_num,
		d.handler_hourly_rate,
		d.clerical_hourly_rate,
		d.mileage_rate,
		d.photograph_rate,
		d.photocopy_rate,
		d.handler_office_percent,
		d.clerical_office_percent,
		d.flat_rate_office_percent,
		d.expense_office_percent,
		d.replication_flag,
		d.on_notice_pct,
		d.billing_service_id,
		d.quantity_num,
		d.rate_amt,
		d.office_pct,
		d.global_tier_yn,
		d.tpa_insured_flag,
		d.dba_name,
		d.cross_reference_num,
		d.email_address,
		d.self_insured_yn,
		d.employer_tier_level,
		d.location_tier_level,
		d.industry_code,
		d.location_number,
		d.ui_number,
		d.pmsi_checking_account,
		d.pmsi_charge_res_type_id,
		d.pmsi_charge_pay_type_id,
		d.pmsi_charge_loss_or_alae,
		d.pmsi_fee_res_type_id,
		d.pmsi_fee_pay_type_id,
		d.pmsi_fee_loss_or_alae,
		d.pmsi_pay_cat_code,
		d.pmsi_exclude_yn,
		d.ccsbr_exclude_yn,
		d.ccsbr_checking_account,
		d.ccsbr_charge_pay_type_id,
		d.ccsbr_charge_res_type_id,
		d.ccsbr_charge_loss_or_alae,
		d.ccsbr_fee_pay_type_id,
		d.ccsbr_fee_res_type_id,
		d.ccsbr_fee_loss_or_alae,
		d.ccsbr_pay_cat_code,
		d.specific_schedule_codes_yn,
		d.analytic_export_yn,
		d.analytic_amount,
		d.analytic_bill_to,
		d.analytic_bill_service,
		d.analytic_bill_charge,
		d.analytic_medical_days,
		d.analytic_diary_handler,
		d.analytic_diary_priority,
		d.analytic_fee_type,
		d.analytic_payee_fed_id,
		d.analytic_payment_type,
		d.analytic_reserve_type,
		d.analytic_financial_type,
		d.certificate_tier_level,
		d.rmis_loc_tier_level




insert into [FHEG].[dbo].[fh_code_client]
select d.*
from [GRAMERCYFHE].[FEGramercy].[dbo].fh_code_client d
where d.tier1_company_id = 'C13339'




insert into [FHEG].[dbo].[fh_code_general]
select d.*
from [GRAMERCYFHE].[FEGramercy].[dbo].fh_code_general d




insert into [FHEG].[dbo].[fh_user]
select d.user_id,
		d.user_type,
		d.user_job,
		d.role_id,
		d.last_name,
		d.first_name,
		d.user_name,
		d.branch_id,
		d.claim_id,
		d.supervisor_id,
		d.next_log_num,
		d.access_day1,
		d.access_day2,
		d.access_day3,
		d.access_day4,
		d.access_day5,
		d.access_day6,
		d.access_day7,
		d.replication_flag,
		d.logon_status,
		d.logon_last_date,
		d.reserve_max,
		d.approve_max,
		d.tier_filter_expression,
		d.assign_claim_yn,
		d.active_user_yn,
		d.alter_pay_type_yn,
		d.brch_sel_on_prt_check_yn,
		d.dial_in_branch_id,
		d.change_note_date_yn,
		d.claim_category_update_yn,
		d.brch_sel_on_view_pay_yn,
		d.diary_other_users_yn,
		d.diary_update_days,
		d.note_access,
		d.note_update_days,
		d.notes_other_user_yn,
		d.other_branch_access_yn,
		d.reserve_update_date_yn,
		d.reserve_update_desc_yn,
		d.third_party_access,
		d.tier_access,
		d.transfer_payment_yn,
		d.update_void_date_yn,
		d.view_confid_claims_yn,
		d.pk_num_beg,
		d.pk_num_end,
		d.internal_use1,
		d.global_handler_yn,
		d.edit_claim_num_yn,
		d.pass_last_changed,
		d.no_fail_attempts,
		d.last_login_attempt,
		d.temp_yn,
		d.pass_expire_days,
		d.email_address,
		d.automation_user_type,
		d.phone_number,
		d.confirm_timeout,
		d.pmsi_login,
		d.pmsi_password,
		d.pmsi_supervisor_yn,
		d.claim_search_sort,
		d.party_search_sort,
		d.email_signature,
		d.title,
		d.fax_number,
		d.menu_bar_style,
		d.menu_collapse_delay,
		d.supervisor_id2,
		d.service_date_override_yn,
		d.imap_host,
		d.imap_port,
		d.imap_username,
		d.imap_password,
		d.imap_folder,
		d.imap_max,
		d.login_ipv4_restricted_yn,
		d.login_ipv4_range_low,
		d.login_ipv4_range_high,
		d.login_ipv6_restricted_yn,
		d.login_ipv6_range_low,
		d.login_ipv6_range_high,
		d.noncheck_max,
		d.view_private_diary_yn,
		d.reserves_by_claim_or_transaction
from [GRAMERCYFHE].[FEGramercy].[dbo].fh_user d




insert into [FHEG].[dbo].[fh_lob]
select d.*
from [GRAMERCYFHE].[FEGramercy].[dbo].fh_lob d




insert into [FHEG].[dbo].[fh_lookup]
select d.*
from [GRAMERCYFHE].[FEGramercy].[dbo].fh_lookup d


commit



set @load_end_dt = GETDATE()

insert into [FHEG].[dbo].[load_info]
values(@load_start_dt, @load_end_dt, @rows)