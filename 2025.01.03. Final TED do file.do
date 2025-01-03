**** JPART paper: The Interplay of Discretion and Complexity in Public Contracting and Renegotiations

clear
set more off

global workspace  "add directory" 

* Importing all the data: useful for JPART paper and other studies using TED
{
*Cleaned CMNs with sentiment scores
{ 
import delimited "$workspace/match_unmatch_sentimentr", varnames(1) clear
keep mod_url element_id word_count sd ave_sentiment
gener cleaning= substr(mod_url,1,8)
	drop if cleaning!="https://" // deleting weird obs
	drop cleaning
save "$workspace/sentiment_info.dta", replace

*Again departing from the same file but saving it differently to merge it with Full CAN data
import delimited "$workspace/match_unmatch_sentimentr", varnames(1) clear
gener cleaning= substr(mod_url,1,8)
	drop if cleaning!="https://" 
	drop cleaning
destring award_notice_id, replace force
save "$workspace/CMN_sentiment_info.dta", replace 

import excel "$workspace\polarity_score", sheet("in") firstrow clear
save "$workspace/polarity_score.dta", replace 


}
*
*CANs from TED
{
import delimited "$workspace/Ted_Award_19_06_filter.csv", varnames(1) clear // 
rename id_notice_can award_notice_id
save "$workspace/FullTED_can.dta", replace

*update - now we have CAN data for 2020 
import delimited "$workspace\TED - Contract award notices 2020.csv", clear 
append using "$workspace/FullTED_can.dta", force

bysort id_notice_can : egen highest_lot = max(award_value_euro)
drop if award_value_euro!=highest_lot & year==2020 // 

drop cae_gpa_annex iso_country_code_gpa tal_location_nuts info_on_non_award  main_cpv_code_gpa  highest_lot
replace award_notice_id=id_notice_can if award_notice_id==.
drop id_notice_can
duplicates drop award_notice_id, force //
save "$workspace/FullTED_can.dta", replace

}
*

*Merging Full CANs + CMNs 
{
use "$workspace/FullTED_can.dta", clear
merge 1:m award_notice_id using "$workspace/CMN_sentiment_info.dta", force // works good, no duplicates in award iD
rename eu_funds eu_funds_delete
rename b_eu_funds eu_funds
replace eu_funds = "Y" if eu_funds=="" & eu_funds_delete=="yes"
replace eu_funds = "N" if eu_funds=="" & eu_funds_delete=="no"
rename award_year award_year_delete
rename year award_year
rename procedure_type procedure_type_delete
rename top_type procedure_type
rename  award_criteria award_criteria_delete
rename crit_code award_criteria
rename contract_type contract_type_delete
rename type_of_contract  contract_type
rename award_id_type award_id_type_delete
rename id_type award_id_type
 
drop id_lot id_award id_lot_awarded  award_year award_url country eu_funds_delete win_nationalid can_win_name can_win_address can_win_town can_win_postcode can_win_countrycode can_win_nat_id can_win_name contract_number lot_id_awarded title  award_year_delete lot_no procedure_type_delete award_criteria_delete can_ca_name can_ca_nat_id can_ca_address can_ca_town can_ca_postcode gpa_code ca_countrycode  iso_country_code_all dt_award contract_type_delete procurer_address contractor_address_orig contractor_address_mod   award_id_type_delete xsd_version

drop if _merge==2 
drop _merge
save "$workspace/FullCAN_CMNs.dta", replace
}


*Supplementary database: OXCGRT data
{

**cleaning OXCGRT data - 22 May 2022
import delimited "$workspace/OxCGRT_latest.csv", varnames(1) clear
	
	*consistent dates
	tostring date, gen(Date1)
	gen datevar=date(Date1,"YMD")
	format datevar %td
	gen date_year= year(datevar)
	gen date_month =month(datevar)
	gen date_day = day(datevar)
	
	rename countryname country_name
	rename countrycode country_code3digits

	*to keep the relevant info
	keep date_year date_month date_day country_name country_code3digits stringencyindex confirmedcases confirmeddeaths //some other vars might be relevant as well, e.g. econ support etc.
	replace stringencyindex=0 if stringencyindex==.
	
	
	collapse  stringencyindex confirmedcases confirmeddeaths, by (country_name country_code3digits date_year date_month date_day) 

save "$workspace/OxCGRT_latest_ms.dta", replace
}
*
}
*
	
* Cleaning data and generating initial "time" useful variables: useful for JPART paper and other studies using TED
{
use "$workspace/FullCAN_CMNs.dta", clear

rename iso_country_code ca_countrycode // so I have it equal to the other dataset (UK + France)

* CMNs vs CANs
gener CMNs=1 if mod_url!=""
	replace CMNs=0 if CMNs!=1

* error in lots
rename total_lots delete
rename lots_number total_lots  // so I have it equal to the other dataset (UK + France)
drop delete
replace total_lots=1 if total_lots==0 // human input error according to the TED guidelines doc
	gen one_lot_only=(total_lots==1) if total_lots!=.
	
* Time variable - useful for several of the next analyes
	*having CANs and CMNs dates separeted per day, month and year
	rename notice_pub_date CMN_date //renaming just to make it clearer it is the modification notice
	drop award_notice_dispatch_date
	rename dt_dispatch CAN_date // had to use this because  contract_award_date is only available for CMNs and then CANs without CMNs wouldnt have dates
	split CMN_date, p("/") // this is better structured already
	split CAN_date, p("-") // more work to be done here to adjust because months are in writen text
		replace CAN_date2="1" if CAN_date2=="JAN"
		replace CAN_date2="2" if CAN_date2=="FEB"
		replace CAN_date2="3" if CAN_date2=="MAR"
		replace CAN_date2="4" if CAN_date2=="APR"
		replace CAN_date2="5" if CAN_date2=="MAY"
		replace CAN_date2="6" if CAN_date2=="JUN"
		replace CAN_date2="7" if CAN_date2=="JUL"
		replace CAN_date2="8" if CAN_date2=="AUG"
		replace CAN_date2="9" if CAN_date2=="SEP"
		replace CAN_date2="10" if CAN_date2=="OCT"
		replace CAN_date2="11" if CAN_date2=="NOV"
		replace CAN_date2="12" if CAN_date2=="DEC"
		destring CMN_date* CAN_date*, replace force
		rename CMN_date1 CMN_date_day
		rename CMN_date2 CMN_date_month
		rename CMN_date3 CMN_date_year
		rename CAN_date1 CAN_date_day
		rename CAN_date2 CAN_date_month
		rename CAN_date3 CAN_date_year
			replace CAN_date_year = CAN_date_year + 2000 // year for CAN was YY instead of YYYY, summing 2000 works because it's only 2000 afterwards
	
*having a unique variable "period" for date of CMN or CAN, considering CMN date when there is one
		gen date_day= CMN_date_day if CMNs==1
			replace date_day= CAN_date_day if CMNs==0
		gen date_month= CMN_date_month if CMNs==1
			replace date_month= CAN_date_month if CMNs==0
		gen date_year= CMN_date_year if CMNs==1
			replace date_year= CAN_date_year if CMNs==0

*generating variable that is properly ordered chronologically for both CAN/CMNs, considering CMN date when there is one
sort date_year date_month date_day
	egen period = group(date_year date_month date_day)
	drop if period==.
save "$workspace/FullCAN_CMNs_final.dta", replace	
}
*

*Considering first CMNs sample and then appending with CANs with no CMNs: useful for JPART paper and other studies using TED
{
*use "$workspace/FullCAN_CMNs_final.dta", clear	
drop if mod_url==""
	bysort award_notice_id (period): gen renegoc_number=_n
	bysort award_notice_id (period): gen renegoc_number_total=_N 
	
*correcting for human input error - I've realised sometimes contracts have the 'difference' instead of proper 'value_before_mod'
destring value_before_mod, replace
destring value_exlvat_orig, replace force
destring value_after_mod, replace

replace value_before_mod= value_exlvat_orig if value_before_mod == (value_after_mod - value_exlvat_orig) // fixing issues with data input

*correcting now for some wrong value_before_mod that were fixed as initial contract value even when it has been changing
rename  value_before_mod value_before_mod_1
bysort award_notice_id (period): gen value_before_mod = value_after_mod[_n-1]
	replace value_before_mod = value_before_mod_1 if renegoc_number==1 // so the first reneg has indeed the inifial value and not something else
	
* gen diff = value_before_mod - value_before_mod_1 // only for assessing how it works; ok
	
	
* renegotiation value
gener pct_change =((value_after_mod-value_before_mod)/value_before_mod)*100
	gener change_value=(pct_change!=0)
	gener increase_value=(pct_change>0 & change_value==1) 
	gener decrease_value=(pct_change<0 & change_value==1)
	
* capturing the cumulated increase in value since the begining for contracts that were renegotiated several times
gen initial_value1=0
	replace initial_value1= value_before_mod if renegoc_number==1
	bysort award_notice_id : egen initial_value = max(initial_value1)
	drop initial_value1

* change in value since the beggining
gener pct_change_cumulative=((value_after_mod - initial_value)/ initial_value )*100

*Creating variables using textual info on modification decription and reason

**** Covid 19****
gener COVID = 0
replace COVID = regexm(modification_reason, "COVID")  | regexm(modification_reason, "Covid") | regexm(modification_reason, "Pandemic") | regexm( modification_reason, "pandemic")| regexm(modification_reason, "lockdown") | regexm(modification_reason, "SARS") | regexm(modification_reason, "Lockdown") | regexm(modification_description, "COVID")  | regexm(modification_description, "Covid") | regexm(modification_description, "Pandemic") | regexm( modification_description, "pandemic")| regexm(modification_description, "lockdown") | regexm(modification_description, "Lockdown") | regexm(modification_description, "SARS") | regexm(modification_description, "Sars")


**** Sustainability ****
* https://onlinelibrary.wiley.com/doi/full/10.1111/jcms.13204
* Quotation from the paper: "Next, we establish an objective measure of GPP adoption across the contracting units. The methodology we employ is to conduct a word search in all the awarding criteria in the contract award notices and in each of the EU's official languages for terms related to green award criteria. We have specifically restricted these words to the ‘environment’ and ‘sustainable’."
gen sustainable= 0
replace sustainable = regexm(modification_reason, "sustainab")  | regexm(modification_reason, "Sustainab") | regexm(modification_reason, "environment")  | regexm(modification_reason, "Environment") | regexm(modification_description, "sustainab")  | regexm(modification_description, "Sustainab") | regexm(modification_description, "environment")  | regexm(modification_description, "Environment") // I've used "Sustainab" instead of "Sustainable" to capture words as "Sustainability". makes sense?


	save "$workspace/FullDatauniqueCMNs.dta", replace


*now for CANs with CMN==0
use "$workspace/FullCAN_CMNs_final.dta", clear
	drop if CMNs==1
	
destring value_before_mod, replace
destring value_exlvat_orig, replace force
destring value_after_mod, replace
	
	append using "$workspace/FullDatauniqueCMNs.dta", force
		
replace renegoc_number = 0 if  renegoc_number==.
replace renegoc_number_total = 0 if renegoc_number_total==.

save "$workspace/FullCAN_CMNs_final.dta", replace
}
*

*Dropping unnecessary variables and creating some other important variables - preparing for regressions and the final working dataset : useful for JPART paper and other studies using TED
{
*use "$workspace/FullCAN_CMNs_final.dta", clear


*merging with Oxford covid data
replace ca_countrycode="GB" if ca_countrycode=="UK" // TED data does not follow the standard 2-digit code for the UK! only country with a problem
rename ca_countrycode country_code2digits

* findit kountry installpackage
kountry country_code2digits, from(iso2c) to (iso3c)
rename _ISO3C_ country_code3digits


* Merging with covid data
merge m:1 country_code3digits date_year date_month date_day using "$workspace/OxCGRT_latest_ms.dta"

drop if _merge==2 // using only, so dates with no contracts
drop _merge
	replace stringencyindex=0 if stringencyindex==. // for periods with no covid (they were the _merge==1)
	replace confirmedcases=0 if confirmedcases==. // for periods with no covid (they were the _merge==1)
	replace confirmeddeaths=0 if confirmeddeaths==. // for periods with no covid (they were the _merge==1)

	

* Non-EU countries with no TED agreement with few obs that shouldnt be listed here
{
drop if country_name=="Zambia"
drop if country_name=="Ukraine"
drop if country_name=="Russia"
drop if country_name=="North Macedonia"
drop if country_name=="Liberia"
drop if country_name=="India"
drop if country_name=="Cambodia"
drop if country_name=="China"
drop if country_name=="Albania"
drop if country_name=="Martinique"
drop if country_name == "Bosnia and Herzegovina"
drop if country_name=="Iceland" // only country with obs in this  dataset, 74 obs deleted only (mostly from 2020, recently included)
}
*

*Encoding variables for regression
encode procedure_type, gen (Cprocedure_type)
encode contract_type, gen (Ccontract_type)
encode country_code3digits, gen (Ccountry_code3digits)
encode award_criteria, gen (Caward_criteria)

*organising and labeling award criteria
replace Caward_criteria=0 if Caward_criteria==1 // price
replace Caward_criteria=1 if Caward_criteria==2 // multi
label define Caward_criteria 0 "Lowest price" 1 "Most advantageous", replace // defining label to be used


*To explore changes within time periods 
gen edate_CAN = mdy(CAN_date_month, CAN_date_day, CAN_date_year)  
gen edate_CMN = mdy(CMN_date_month, CMN_date_day, CMN_date_year)  
gen reneg_time_days= edate_CMN-edate_CAN  
*number of changes within the first year
bysort award_notice_id: egen reneg_count_total_1=sum(CMNs) if reneg_time_days<=365
replace reneg_count_total_1=0 if reneg_count_total_1==.
	gen CMNs_1year=CMNs
	replace CMNs_1year=0 if reneg_time_days>365
*number of changes within the first 2 years
bysort award_notice_id: egen reneg_count_total_2=sum(CMNs) if reneg_time_days<=730
replace reneg_count_total_2=0 if reneg_count_total_2==.
	gen CMNs_2year=CMNs
	replace CMNs_2year=0 if reneg_time_days>730
*number of changes within the first 3 years
bysort award_notice_id: egen reneg_count_total_3=sum(CMNs) if reneg_time_days<=1095
replace reneg_count_total_3=0 if reneg_count_total_3==.
	gen CMNs_3year=CMNs
	replace CMNs_3year=0 if reneg_time_days>1095


*Creating duration variable (CMNs data only)

destring contract_dur_days_mod, replace
destring contract_dur_days_orig, replace force

gen change_duration_days=.
replace change_duration_days = contract_dur_days_mod - contract_dur_days_orig

gen pct_change_duration=((contract_dur_days_mod-contract_dur_days_orig)/contract_dur_days_orig)*100

	gener change_duration=(change_duration_days!=0) if change_duration_days!=.
	gener increase_duration=(change_duration_days>0) if change_duration_days!=.
	gener decrease_duration=(change_duration_days<0) if change_duration_days!=.
	
* capturing the cumulated increase in duration since the begining for contracts that were renegotiated several times
gen initial_value1_d=0
	replace initial_value1_d= contract_dur_days_orig if renegoc_number==1
	bysort award_notice_id : egen initial_value_d = max(initial_value1_d)
	drop initial_value1_d
gen pct_change_duration_c=((contract_dur_days_mod-initial_value_d)/initial_value_d)*100


*CPV code as control - but take care because this is for CMN ONLY! NOT REALLY, i'VE IT FOR THE FULL CAN AS WELL IF i'VE USED 'cpv' instead of 'cpv_code_orig'

*** CPV codes 2 digits ***
gener CPVSTRING= substr(cpv_code_orig,1,8) 
destring CPVSTRING, gen(CPVTEMP) force
gener CPV=CPVTEMP/1000000
gener Ccpv2digits = int(CPV)
drop CPVTEMP CPV CPVSTRING

*** CPV codes 3 digits ***
gener CPVSTRING1= substr(cpv_code_orig,1,8) 
destring CPVSTRING1, gen(CPVTEMP) force
gener CPV1=CPVTEMP/100000
gener Ccpv3digits = int(CPV1)
drop CPVTEMP CPV1 CPVSTRING1


*** drop if cancelled
drop if cancelled==1
drop cancelled

*other useless variables
drop number_tenders_other // repeated
drop contract_award_date // CAN date in the CMN dataset, not useful and with missings. We are already using CAN date from the CAN dataset
drop CMN_date // I'd split this already in day month year
drop CAN_date // I'd split this already in day month year
drop b_multiple_cae // many missings
drop b_multiple_country // many missings
drop b_involves_joint_procurement b_awarded_by_central_body b_dyn_purch_syst additional_cpvs // missings
drop crit_price_weight // too bad quality
drop info_unpublished // this is not in the TED dictionary
drop contract_dur_months_mod contract_dur_months_orig contract_enddate_orig contract_startdate_mod contract_enddate_mod // missings, and we are already using other variables for determining change in duration (contract_dur_days_orig contract_dur_days_mod)
drop additional_cpv_code_orig // missings, and not that useful anyways, I've the CPV in CAN dataset and I already didn't use the additional ones there
drop criteria_price_weight // the CMN-version of crit_price_weight, bad quality
drop number_tenders_other // CMN-version, not useful

rename mod_url mod_url1
gen mod_url=mod_url1
merge m:1 mod_url using "$workspace/polarity_score.dta" // this consider the Python package TextBlob
 drop mod_url1 _merge

save "$workspace/FullCAN_CMNs_final.dta", replace 
}
*

*JPART paper: focusing on this study key variables
{
use "$workspace/FullCAN_CMNs_final.dta", clear 
drop if CAN_date_year<2016 // from 41,776  to  36,314  CMNs
drop if renegoc_number_total>10 // from 36,314  to  23,761  CMNs
drop if award_value_euro < 1000 // ... to 23,153 CMNs 
drop if pct_change > 90 & pct_change!=. // to  21,897 CMNs
drop if pct_change < -90 & pct_change!=. // to  21,689 CMNs
drop if pct_change_cumulative > 200 & pct_change_cumulative!=. // to  21,371 CMNs
drop if pct_change_cumulative < -90 & pct_change_cumulative!=. // 21,307  CMNs
drop if Cprocedure_type==1 | Cprocedure_type==3 // to 21,117 CMNs

gener discretionary_proc=0 if Cprocedure_type==8 | Cprocedure_type==9 // RES and OPE have no 'negotiation rounds'
replace discretionary_proc=1 if discretionary_proc!=0

gen discretionary_criteria=Caward_criteria

gener discrete=0
replace discrete=1 if discretionary_criteria ==1 | discretionary_proc==1

*additional three-level measure
gener discrete_alt=0
replace discrete_alt=1 if discretionary_criteria ==1 | discretionary_proc==1 
replace discrete_alt=2 if discretionary_criteria ==1 & discretionary_proc==1 

encode cae_type, gen (Ccae_type)


*labeling ca_type
label define Ccae_type 1 "Ministry or any other national or federal authority, including their regional of local subdivisions" 2 "Regional or local authority" 3 "Water, energy, transport and telecommunications sectors" 4 "European Union institution/agency"  5 "other international organisation" 6 "Body governed by public law" 7 "Other"  8 "National or federal Agency / Office"  9 "Regional or local Agency / Office" 10 "Not specified" , replace



*1 "Ministry or any other national or federal authority, including their regional of local subdivisions"
*3 "Regional or local authority"
*4 "Water, energy, transport and telecommunications sectors"
*5 "European Union institution/agency" 
*5A "other international organisation"
*6 "Body governed by public law"
*8 "Other" 
*N "National or federal Agency / Office" 
*R "Regional or local Agency / Office"
*Z "Not specified"

*how fast they renegotiated
gen speed_reneg_slow= reneg_time_days/contract_dur_days_orig

{
*Complexity components:
generate framework_agreement=1 if b_fra_agreement=="Y"
replace framework_agreement=0 if framework_agreement==.
gen jointly_procured=1 if  joint_procurement=="Y"
replace jointly_procured=0 if  jointly_procured==.
replace jointly_procured=1 if  b_on_behalf=="Y"
gen mult_contract_auth=1 if multiple_ca =="Y"
replace mult_contract_auth=0 if mult_contract_auth==.
tab ca_multi_countrycode 
gen mult_countries=1 if multiple_country =="Y"
replace  mult_countries=0 if  mult_countries==.
gen serv_contract=1 if Ccontract_type==1
replace serv_contract=0 if serv_contract==.
gen work_serv_contract=1 if Ccontract_type~=2
replace work_serv_contract=0 if work_serv_contract==.
gen group_award=1 if b_awarded_to_a_group=="Y"
replace group_award=0 if group_award==.

*Complexity indicators addressing missingness
gen subcontracted2=1 if b_subcontracted =="Y"
replace subcontracted2=0 if subcontracted2==. & b_subcontracted ~= ""
generate framework_agreement2=1 if b_fra_agreement=="Y"
replace framework_agreement2=0 if framework_agreement2==. 
gen jointly_procured2=1 if  joint_procurement=="Y"
replace jointly_procured2=0 if  jointly_procured2==. & joint_procurement~= ""
replace jointly_procured2=1 if  b_on_behalf=="Y"
gen mult_contract_auth2=1 if multiple_ca =="Y"
replace mult_contract_auth2=0 if mult_contract_auth2==. & multiple_ca~= ""
gen mult_countries2=1 if multiple_country =="Y"
replace  mult_countries2=0 if  mult_countries2==. & multiple_country~= ""
gen serv_contract2=1 if Ccontract_type==1
replace serv_contract2=0 if serv_contract2==. & Ccontract_type~= .
gen work_serv_contract2=1 if Ccontract_type~=2
replace work_serv_contract2=0 if work_serv_contract2==. & Ccontract_type~= .
gen group_award2=1 if b_awarded_to_a_group=="Y"
replace group_award2=0 if group_award==. & b_awarded_to_a_group~= ""

*Revised measure of multi-party contracts for complexity4 measure
gen multiparty=1 if mult_countries==1
replace multiparty=1 if mult_contract_auth ==1
replace multiparty=1 if group_award ==1
replace multiparty=0 if multiparty ==. &  b_awarded_to_a_group~= ""


*Measure of complexity (original scalar of 7 indictor variables)
gen complexity= subcontracted+ framework_agreement+ jointly_procured+ mult_contract_auth+ mult_countries+ group_award+ work_serv_contract

*Testing if only service contracts should be considered complex – answer is "no"
gen complexity2= subcontracted+ framework_agreement+ jointly_procured+ mult_contract_auth+ mult_countries+ group_award+ serv_contract

*Addressing missing values on indicators
gen complexity3= subcontracted2+ framework_agreement2+ jointly_procured2+ mult_contract_auth2+ mult_countries2+ group_award2+ work_serv_contract2

*Preferred measure of complexity
gen complexity4= subcontracted2+ framework_agreement2+ jointly_procured2+ multiparty + work_serv_contract2


*Categorical measures of complexity:
gen nocomplexity=1 if complexity4==0
replace nocomplexity=0 if nocomplexity==. & complexity4~=.
gen lowcomplexity=1 if complexity4==1
replace lowcomplexity=0 if lowcomplexity==. & complexity4~=.
gen medcomplexity=1 if complexity4==2
replace medcomplexity=0 if medcomplexity==. & complexity4~=.
gen highcomplexity=1 if complexity4>2
replace highcomplexity=0 if highcomplexity==. & complexity4~=.

*Interaction terms
gen discrete_lowcomp=discrete*lowcomplexity
gen discrete_medcomp=discrete*medcomplexity
gen discrete_highcomp=discrete*highcomplexity
gen discrit_lowcomp= discretionary_criteria*lowcomplexity
gen discrit_medcomp= discretionary_criteria*medcomplexity
gen discrit_highcomp= discretionary_criteria*highcomplexity
gen disproc_lowcomp= discretionary_proc*lowcomplexity
gen disproc_medcomp= discretionary_proc*medcomplexity
gen disproc_highcomp= discretionary_proc*highcomplexity
gen discrete_comp4= discrete*complexity4
gen discrit_comp4= discretionary_criteria*complexity4
gen disproc_comp4= discretionary_proc*complexity4

*New DV
gen reneg_time_days2= reneg_time_days
replace reneg_time_days2=. if reneg_time_days2<0
gen lnreneg_time_days=ln(reneg_time_days2)
}

*Important to have as control the 'number of the reneg in terms of value'
bysort award_notice_id (period): gen renegoc_value_number=_n if change_value==1
bysort award_notice_id (period): gen renegoc_value_total=_N if change_value==1
replace renegoc_value_total = 0 if renegoc_value_total==.

*Additional variables that are only in CMN data

encode contractor_sme_mod, gen(sme)
replace sme= sme-1
label define sme 0 "No SME" 1 "SME", replace 

encode b_subcontracted, gen(subcontracted)
replace subcontracted = subcontracted -1
label define subcontracted 0 "Not subcontracted" 1 "Subcontracted", replace 

	save "$workspace\Final working datasets\FullCAN_CMNs_final_relational.dta", replace
	use "$workspace\Final working datasets\FullCAN_CMNs_final_relational.dta", clear
	
	
	replace lnreneg_time_days=. if renegoc_number>1 // this should be the first time ever the contract was renegotiated, if collapsed

replace pct_change_cumulative=. if renegoc_value_number!=renegoc_value_total // so the collapse takes the last value for these, the max wasn't necessarily the last
replace pct_change_duration_c=. if renegoc_number!=renegoc_number_total // same

replace speed_reneg_slow=. if renegoc_number>1 // this should be the first time ever the contract was renegotiated, if collapsed

collapse discrete discrete_alt lnreneg_time_days complexity4 discrete_comp4  discretionary_criteria discretionary_proc number_offers speed_reneg_slow change_duration_days renegoc_number_total renegoc_value_total COVID sustainable  Ccpv2digit Ccpv3digits award_value_euro  sd word_count  ave_sentiment polarity_score element_id CAN_date_year CAN_date_month stringencyindex confirmedcases confirmeddeaths (max) CMN_date_year (max) CMN_date_month (max) pct_change_cumulative (max) pct_change_duration_c (min) reneg_time_days, by(sme subcontracted award_notice_id Ccountry_code3digits Cprocedure_type Ccontract_type Caward_criteria Ccae_type)

*PSM
set seed 123123
gen aleatorio = uniform()
order aleatorio
sort aleatorio

psmatch2 discrete number_offers award_value_euro  i.Ccountry_code3digits  i.Ccae_type i.Ccontract_type i.subcontracted i.CAN_date_year##i.CAN_date_month, out(renegoc_number_total) n(1) norepl
rename _weight _w1
replace _w1=0 if _w1==. /// =0 not matched, =1 matched

*labeling CPVs
label define Ccpv2digits 1 "Agricultural, farming, fishing, forestry and related products" 2 "Petroleum products, fuel, electricity and other sources of energy" 14 "Mining, basic metals and related products" 15 "Food, beverages, tobacco and related products" 16 "Agricultural machinery" 18 "Clothing, footwear, luggage articles and accessories"  19"Leather and textile fabrics, plastic and rubber materials" 22 "Printed matter and related products" 24 "Chemical products" 30 "Office and computing machinery, equipment and supplies except furniture and software packages" 31 "Electrical machinery, apparatus, equipment and consumables; Lighting" 32 "Radio, television, communication, telecommunication and related equipment" 33 "Medical equipments, pharmaceuticals and personal care products" 34 "Transport equipment and auxiliary products to transportation" 35 "Security, fire-fighting, police and defence equipment" 37 "Musical instruments, sport goods, games, toys, handicraft, art materials and accessories" 38  "Laboratory, optical and precision equipments (excl. gl37asses)" 41 "Furniture (incl. office furniture), furnishings, domestic appliances (excl. lighting) and cleaning products" 39 "Collected and purified water" 42 "Industrial machinery" 43"Machinery for mining, quarrying, construction equipment" 44 "Construction  and materials; auxiliary products to construction (excepts electric apparatus)" 45 "Construction work" 48 "Software package and information systems" 50 "Repair and maintenance services" 51 "Installation services (except software)" 55 "Hotel, restaurant and retail trade services" 60 "Transport services (excl. Waste transport)" 63 "Supporting and auxiliary transport services; travel agencies services" 64 "Postal and telecommunications services" 65 "Public utilities" 66 "Financial and insurance services" 70 "Real estate services" 71 "Architectural, construction, engineering and inspection services" 72 "IT services: consulting, software development, Internet and support" 73 "Research and development services and related consultancy services" 75 "Administration, defence and social security services" 76 "Services related to the oil and gas industry" 77 "Agricultural, forestry, horticultural, aquacultural and apicultural services" 79 "Business services: law, marketing, consulting, recruitment, printing and security" 80 "Education and training services" 85 "Health and social work services" 90 "Sewage-, refuse-, cleaning-, and environmental services" 92 "Recreational, cultural and sporting services" 98 "Other community, social and personal services", replace

*re-doing 'contract renegotiated' variable
gen CMNs=0 if renegoc_number_total==0
	replace CMNs=1 if renegoc_number_total>0 // now CMNs=1 means that contract was renegotiated at some point, =0 otherwise (never renegotiated)
	
	
* droping contracts that changed CPV (very few)
gen teste=int(Ccpv2digits)
	gen teste2= teste - Ccpv2digits
	drop if teste2<0
	drop teste teste2

save "$workspace\Final working datasets\CollapsedCAN_CMNs_final_relational.dta", replace
}
*

* Initially exploring descriptives and data pattern
{ 
use "$workspace\Final working datasets\FullCAN_CMNs_final_relational.dta", clear 


*PS: the graph for figure 1 considers the CAN-level data so it comes in the next chunks

bysort country_code3digits: egen CMNs_country=sum(CMNs)

gen counting_cans = 0
replace counting_cans = 1 if renegoc_number_total==0 //adding 1 for CANs what were never renegotiated
replace counting_cans = 1 if renegoc_number_total>0 & renegoc_number==1 //adding 1 for CANs what were  renegotiated (only 1 time, for the first reneg)
tab counting_cans CMNs
bysort country_code3digits: egen CANs_country=sum(counting_cans)


gen cmns_per_cans_country = CMNs_country/CANs_country

*Graphs per country 


*title ("Average of renegotiations per contract renegotiated per country") (THIS CONTINUES AS THE FIGURE 3)
	graph bar renegoc_number_total,   over(country_code3digits, sort(renegoc_number_total) descending label(angle(45)) ) ytitle ("Average of renegotiations per contract") graphregion(color(white)) // as title
	*COMMENT: there are pretty much the same as what you had before, if I remember it right
		graph save "Graph" "$workspace\Stata outputs\Graphs\country_cmnspercans1.gph", replace
		graph export "$workspace\Stata outputs\Graphs\country_cmnspercans1.png", as(png) name("Graph")	 replace


* title("Number of CMNs per country")  (THIS IS THE NEW FIGURE 2)
	graph bar (mean) cmns_per_cans_country , over(country_code3digits, sort(1) descending  label(angle(45)) )  ytitle("# of CMNs per CANs") graphregion(color(white)) // number of CMNs/CANs per country (I'm double counting when a CAN has multiple CMNs')
		graph save "Graph" "$workspace\Stata outputs\Graphs\country_cmns_cans1.gph", replace
		graph export "$workspace\Stata outputs\Graphs\country_cmns_can1s.png", as(png) name("Graph") replace

* title("Number of CMNs per country")  (THIS WAS THE FORMER FIGURE 2)
	graph bar (count) if CMNs==1, over(country_code3digits, sort(1) descending  label(angle(45)) )  ytitle("# of CMNs") graphregion(color(white)) // number of CMNs per country (I'm double counting when a CAN has multiple CMNs')
		graph save "Graph" "$workspace\Stata outputs\Graphs\country_cmns.gph", replace
		graph export "$workspace\Stata outputs\Graphs\country_cmns.png", as(png) name("Graph") replace
	
* title("Number of new renegotiated contracts per country") (THIS WASNT USED BEFORE)
	graph bar (count) if CMNs==1 & renegoc_number==1, over(country_code3digits, sort(1) descending  label(angle(45)) ) ytitle("# of CANs renegotiated") graphregion(color(white)) // number of CANs with a CMN per country (not double counting CANs)
		graph save "Graph" "$workspace\Stata outputs\Graphs\country_renegotiatedcans.gph", replace
		graph export "$workspace\Stata outputs\Graphs\country_renegotiatedcans.png", as(png) name("Graph") replace

*title ("Average of renegotiations per contract renegotiated per country") (THIS CONTINUES AS THE FIGURE 3)
	graph bar renegoc_number_total if CMNs==1,   over(country_code3digits, sort(renegoc_number_total) descending label(angle(45)) ) ytitle ("Average of renegotiations per contract") graphregion(color(white)) // as title
	*COMMENT: there are pretty much the same as what you had before, if I remember it right
		graph save "Graph" "$workspace\Stata outputs\Graphs\country_cmnspercans.gph", replace
		graph export "$workspace\Stata outputs\Graphs\country_cmnspercans.png", as(png) name("Graph")	 replace



* and then I continue with the subsample of renegotiated contracts
drop if CMNs==0 // the following analyses should consider only the subsample of reneg contracts

*time trends CMN
sort CMN_date_year CMN_date_month CMN_date_day
gen time_lineCMN=CMN_date_year+(CMN_date_month/100)

*unique identifiers for year-month pairs CMN
egen time_trendCMN = group(time_lineCMN)
sort time_trendCMN


*time trends CMN
sort CAN_date_year CAN_date_month CAN_date_day
gen time_lineCAN=CAN_date_year+(CAN_date_month/100)

*unique identifiers for year-month pairs CMN
egen time_trendCAN = group(time_lineCAN)
sort time_trendCAN

gen datevar = mdy(CMN_date_month, CMN_date_day, CMN_date_year)
gen seasonal_quarter = ceil(month(datevar)/3)

save "$workspace\Final working datasets\FullCMNs_final_relational.dta", replace 


}
*

*Main analyses: PSM and regressions
{
use "$workspace\Final working datasets\FullCMNs_final_relational.dta", clear 

	
*PSM (last specification)
set seed 123123
gen aleatorio = uniform()
order aleatorio
sort aleatorio

psmatch2 discretionary_criteria c.complexity4 discretionary_proc i.COVID i.sustainable stringencyindex award_value_euro i.sme  i.Ccae_type i.Ccountry_code3digits i.Ccpv2digits  i.CMN_date_year i.CMN_date_month  i.CAN_date_year i.CAN_date_month, out(polarity_score) n(1) norepl
rename _weight psm_1
replace psm_1=0 if psm_1==. /// =0 not matched, =1 matched



psmatch2 discretionary_criteria c.complexity4 discretionary_proc i.COVID i.sustainable stringencyindex award_value_euro i.sme  i.Ccae_type i.Ccountry_code3digits i.Ccpv2digits  i.CMN_date_year i.CMN_date_month  i.CAN_date_year i.CAN_date_month, out(lnreneg_time_days) n(1) norepl
rename _weight psm_2
replace psm_2=0 if psm_2==. /// =0 not matched, =1 matched


psmatch2 discretionary_criteria c.complexity4 discretionary_proc i.COVID i.sustainable stringencyindex award_value_euro i.sme  i.Ccae_type i.Ccountry_code3digits i.Ccpv2digits  i.CMN_date_year i.CMN_date_month  i.CAN_date_year i.CAN_date_month, out(pct_change) n(1) norepl
rename _weight psm_3
replace psm_3=0 if psm_3==. /// =0 not matched, =1 matched
	

**********H1a & h2a

regress polarity_score discretionary_criteria complexity4, cluster(award_notice_id ) // no controls nor interaction
outreg2 using discretionH1a_RRSMJ, noaster pvalue dec(4) replace excel ctitle(No Controls)

regress polarity_score c.discretionary_criteria##c.complexity4, cluster(award_notice_id ) // add interaction
outreg2 using discretionH1a_RRSMJ, noaster pvalue dec(4) append excel ctitle(Add moderation)

regress polarity_score c.discretionary_criteria##c.complexity4 discretionary_proc i.COVID i.sustainable stringencyindex award_value_euro i.sme, cluster(award_notice_id ) // add controls 
outreg2 using discretionH1a_RRSMJ, noaster pvalue dec(4) append excel ctitle(Controls)

regress polarity_score c.discretionary_criteria##c.complexity4  discretionary_proc i.COVID i.sustainable stringencyindex award_value_euro i.sme  i.Ccae_type i.Ccountry_code3digits i.Ccpv2digits  i.CMN_date_year##i.CMN_date_month  i.CAN_date_year##i.CAN_date_month, cluster(award_notice_id ) // add CAN + CMN dates and other FE
outreg2 using discretionH1a_RRSMJ, noaster pvalue dec(4) append excel ctitle(FE)

gen sample_1=e(sample)


regress polarity_score c.discretionary_criteria##c.complexity4  discretionary_proc i.COVID i.sustainable stringencyindex award_value_euro i.sme  i.Ccae_type i.Ccountry_code3digits i.Ccpv2digits  i.CMN_date_year##i.CMN_date_month  i.CAN_date_year##i.CAN_date_month if psm_1==1, cluster(award_notice_id ) // add CAN + CMN dates and other FE
outreg2 using discretionH1a_RRSMJ, noaster pvalue dec(4) append excel ctitle(PSM)



margins, dydx(discretionary_criteria) at(complexity4=( 0(1)5)) vsquish
marginsplot, scheme(sj) level(95) yline(0)


* what if we do these analyses only for COVID-related renegs? also works

regress polarity_score discretionary_criteria complexity4 if COVID==1, cluster(award_notice_id ) // no controls nor interaction
outreg2 using discretionH1a_RRSMJcovid, noaster pvalue dec(4) replace excel ctitle(No Controls)

regress polarity_score c.discretionary_criteria##c.complexity4 if COVID==1, cluster(award_notice_id ) // add interaction
outreg2 using discretionH1a_RRSMJcovid, noaster pvalue dec(4) append excel ctitle(Add moderation)

regress polarity_score c.discretionary_criteria##c.complexity4 discretionary_proc i.sustainable stringencyindex award_value_euro i.sme if COVID==1, cluster(award_notice_id ) // add controls 
outreg2 using discretionH1a_RRSMJcovid, noaster pvalue dec(4) append excel ctitle(Controls)

regress polarity_score c.discretionary_criteria##c.complexity4  discretionary_proc i.sustainable stringencyindex award_value_euro i.sme  i.Ccae_type i.Ccountry_code3digits i.Ccpv2digits  i.CMN_date_year##i.CMN_date_month  i.CAN_date_year##i.CAN_date_month if COVID==1, cluster(award_notice_id ) // add CAN + CMN dates and other FE
outreg2 using discretionH1a_RRSMJcovid, noaster pvalue dec(4) append excel ctitle(FE)

regress polarity_score c.discretionary_criteria##c.complexity4  discretionary_proc i.sustainable stringencyindex award_value_euro i.sme  i.Ccae_type i.Ccountry_code3digits i.Ccpv2digits  i.CMN_date_year##i.CMN_date_month  i.CAN_date_year##i.CAN_date_month if COVID==1 & psm_1==1, cluster(award_notice_id ) // add CAN + CMN dates and other FE
outreg2 using discretionH1a_RRSMJcovid, noaster pvalue dec(4) append excel ctitle(PSM)

margins, dydx(discretionary_criteria) at(complexity4=( 0(1)5)) vsquish
marginsplot, scheme(sj) level(95) yline(0)

**********H1b & h2b

regress lnreneg_time_days discretionary_criteria complexity4, cluster(award_notice_id ) // no controls nor interaction
outreg2 using discretionH1b_RRSMJ, noaster pvalue dec(4) replace excel ctitle(No Controls)

regress lnreneg_time_days c.discretionary_criteria##c.complexity4, cluster(award_notice_id ) // add interaction
outreg2 using discretionH1b_RRSMJ, noaster pvalue dec(4) append excel ctitle(Add moderation)

regress lnreneg_time_days c.discretionary_criteria##c.complexity4 discretionary_proc i.COVID i.sustainable stringencyindex award_value_euro i.sme, cluster(award_notice_id ) // add controls 
outreg2 using discretionH1b_RRSMJ, noaster pvalue dec(4) append excel ctitle(Controls)

regress lnreneg_time_days c.discretionary_criteria##c.complexity4  discretionary_proc i.COVID i.sustainable stringencyindex award_value_euro i.sme  i.Ccae_type i.Ccountry_code3digits i.Ccpv2digits  i.CMN_date_year##i.CMN_date_month  i.CAN_date_year##i.CAN_date_month, cluster(award_notice_id ) // add CAN + CMN dates and other FE
outreg2 using discretionH1b_RRSMJ, noaster pvalue dec(4) append excel ctitle(FE)

gen sample_2=e(sample)


regress lnreneg_time_days c.discretionary_criteria##c.complexity4  discretionary_proc i.COVID i.sustainable stringencyindex award_value_euro i.sme  i.Ccae_type i.Ccountry_code3digits i.Ccpv2digits  i.CMN_date_year##i.CMN_date_month  i.CAN_date_year##i.CAN_date_month if psm_2==1, cluster(award_notice_id ) // add CAN + CMN dates and other FE
outreg2 using discretionH1b_RRSMJ, noaster pvalue dec(4) append excel ctitle(PSM)



margins, dydx(discretionary_criteria) at(complexity4=( 0(1)5)) vsquish
marginsplot, scheme(sj) level(95) yline(0)


****** opportunism or what? former H3 - results were  similar to what we had before

regress pct_change discretionary_criteria complexity4, cluster(award_notice_id ) // no controls nor interaction
outreg2 using discretion_rob1_RRSMJ, noaster pvalue dec(4) replace excel ctitle(No Controls)

regress pct_change c.discretionary_criteria##c.complexity4, cluster(award_notice_id ) // add interaction
outreg2 using discretion_rob1_RRSMJ, noaster pvalue dec(4) append excel ctitle(Add moderation)

regress pct_change c.discretionary_criteria##c.complexity4 discretionary_proc i.COVID i.sustainable stringencyindex award_value_euro i.sme, cluster(award_notice_id ) // add controls 
outreg2 using discretion_rob1_RRSMJ, noaster pvalue dec(4) append excel ctitle(Controls)

regress pct_change c.discretionary_criteria##c.complexity4  discretionary_proc i.COVID i.sustainable stringencyindex award_value_euro i.sme  i.Ccae_type i.Ccountry_code3digits i.Ccpv2digits  i.CMN_date_year##i.CMN_date_month  i.CAN_date_year##i.CAN_date_month, cluster(award_notice_id ) // add CAN + CMN dates and other FE
outreg2 using discretion_rob1_RRSMJ, noaster pvalue dec(4) append excel ctitle(FE)

gen sample_3=e(sample)

regress pct_change c.discretionary_criteria##c.complexity4  discretionary_proc i.COVID i.sustainable stringencyindex award_value_euro i.sme  i.Ccae_type i.Ccountry_code3digits i.Ccpv2digits  i.CMN_date_year##i.CMN_date_month  i.CAN_date_year##i.CAN_date_month if psm_3==1, cluster(award_notice_id ) // add CAN + CMN dates and other FE
outreg2 using discretion_rob1_RRSMJ, noaster pvalue dec(4) append excel ctitle(PSM)



gen sample_s= sample_1 + sample_2 + sample_3



*Descriptives considering also the observations for the sample with full data
asdoc sum polarity_score reneg_time_days2 pct_change pct_change_cumulative discretionary_criteria  complexity4 discretionary_proc COVID sustainable stringencyindex award_value_euro sme
asdoc sum polarity_score reneg_time_days2 pct_change pct_change_cumulative discretionary_criteria  complexity4 discretionary_proc COVID sustainable stringencyindex award_value_euro sme if sample_s==3




*** Robustness: now considering the binary variable

gen red_flag=.
replace red_flag=1 if pct_change>50
replace red_flag=0 if pct_change<=50

regress red_flag discretionary_criteria complexity4, cluster(award_notice_id ) // no controls nor interaction
outreg2 using discretion_rob2_RRSMJ, noaster pvalue dec(4) replace excel ctitle(No Controls)

regress red_flag c.discretionary_criteria##c.complexity4, cluster(award_notice_id ) // add interaction
outreg2 using discretion_rob2_RRSMJ, noaster pvalue dec(4) append excel ctitle(Add moderation)

regress red_flag c.discretionary_criteria##c.complexity4 discretionary_proc i.COVID i.sustainable stringencyindex award_value_euro i.sme, cluster(award_notice_id ) // add controls 
outreg2 using discretion_rob2_RRSMJ, noaster pvalue dec(4) append excel ctitle(Controls)

regress red_flag c.discretionary_criteria##c.complexity4  discretionary_proc i.COVID i.sustainable stringencyindex award_value_euro i.sme  i.Ccae_type i.Ccountry_code3digits i.Ccpv2digits  i.CMN_date_year##i.CMN_date_month  i.CAN_date_year##i.CAN_date_month, cluster(award_notice_id ) // add CAN + CMN dates and other FE
outreg2 using discretion_rob2_RRSMJ, noaster pvalue dec(4) append excel ctitle(FE)

regress red_flag c.discretionary_criteria##c.complexity4  discretionary_proc i.COVID i.sustainable stringencyindex award_value_euro i.sme  i.Ccae_type i.Ccountry_code3digits i.Ccpv2digits  i.CMN_date_year##i.CMN_date_month  i.CAN_date_year##i.CAN_date_month if psm_3==1, cluster(award_notice_id ) // add CAN + CMN dates and other FE
outreg2 using discretion_rob2_RRSMJ, noaster pvalue dec(4) append excel ctitle(PSM)

margins, dydx(discretionary_criteria) at(complexity4=( 0(1)5)) vsquish
marginsplot, scheme(sj) level(95) yline(0)


*** Robustness: now considering the  other red flag at the award-stage


regress number_offers discretionary_criteria complexity4, cluster(award_notice_id ) // no controls nor interaction
outreg2 using discretion_rob3_RRSMJ, noaster pvalue dec(4) replace excel ctitle(No Controls)

regress number_offers c.discretionary_criteria##c.complexity4, cluster(award_notice_id ) // add interaction
outreg2 using discretion_rob3_RRSMJ, noaster pvalue dec(4) append excel ctitle(Add moderation)

regress number_offers c.discretionary_criteria##c.complexity4 discretionary_proc i.COVID i.sustainable stringencyindex award_value_euro i.sme, cluster(award_notice_id ) // add controls 
outreg2 using discretion_rob3_RRSMJ, noaster pvalue dec(4) append excel ctitle(Controls)

regress number_offers c.discretionary_criteria##c.complexity4  discretionary_proc i.COVID i.sustainable stringencyindex award_value_euro i.sme  i.Ccae_type i.Ccountry_code3digits i.Ccpv2digits  i.CMN_date_year##i.CMN_date_month  i.CAN_date_year##i.CAN_date_month, cluster(award_notice_id ) // add CAN + CMN dates and other FE
outreg2 using discretion_rob3_RRSMJ, noaster pvalue dec(4) append excel ctitle(FE)

margins, dydx(discretionary_criteria) at(complexity4=( 0(1)5)) vsquish
marginsplot, scheme(sj) level(95) yline(0)

}


* To re-run figures with margin plots
{
*Figure 2
regress polarity_score c.discretionary_criteria##c.complexity_new  discretionary_proc i.COVID i.sustainable stringencyindex award_value_euro i.sme  i.Ccae_type i.Ccountry_code3digits i.Ccpv2digits  i.CMN_date_year##i.CMN_date_month  i.CAN_date_year##i.CAN_date_month if psm_1==1, cluster(award_notice_id ) // add CAN + CMN dates and other FE

margins, dydx(discretionary_criteria) at(complexity_new=( 0(1)4)) vsquish
marginsplot, scheme(sj) level(95) yline(0)

*Figure 3
regress lnreneg_time_days c.discretionary_criteria##c.complexity_new  discretionary_proc i.COVID i.sustainable stringencyindex award_value_euro i.sme  i.Ccae_type i.Ccountry_code3digits i.Ccpv2digits  i.CMN_date_year##i.CMN_date_month  i.CAN_date_year##i.CAN_date_month if psm_2==1, cluster(award_notice_id ) // add CAN + CMN dates and other FE

margins, dydx(discretionary_criteria) at(complexity_new=( 0(1)4)) vsquish
marginsplot, scheme(sj) level(95) yline(0)
}





