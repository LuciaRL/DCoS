/* -----------------------------------------------------------------------------

     WFP - Policy and Programme Division - Analysis & Trends Service 
		   Economic and Market Analysis Unit 
		   
     CONTACT: Lucia Latino 
			  lucia.latino@wfp.org
			  Latino@Economia.uniroma2.it
      
	 AIM: convert Somalia prices in USD, compute national average,
		set price series priority, set data requirements, detect and impute outliers
     
----------------------------------------------------------------------------- */




*** Clear environment 
	clear
	set more off
	set maxvar 20000	
	
*** get country-specific commodity caloric contribution for a diet of 2010 kcal/person/day
	import excel $path\input\BigTable_Tool.xlsx, sheet("Master_List") cellrange(A3) firstrow clear
	drop if adm0_name ==""
	rename um_id unit
	rename pt_id pt
	save $path\input\list_master, replace

*** get exchange rate for Somalia
	import excel $path\input\BigTable_Tool.xlsx, sheet("Somalia_ExchangeRate") cellrange(B7) firstrow clear
	rename YearMonthCurrency year
	rename C month 
	keep year month SoSh SlSh
	gen adm0_name="Somalia"
	drop if SoSh==. 
	save $path\input\exch_rate_somalia, replace

*******************************************	
*	merge VAM and GIEWS data and		  *
* keep only country RMPB is interested in *
*******************************************
	clear
	use $path/output/data_wfp.dta
	merge 1:1 adm0_id mkt_id cm_id pt cur_id month year using $path/output/data_giews.dta
	drop _merge

	label define ext_data 0 "WFP" 1 "FAO"
	label value ext_data ext_data
	
	order  adm0* mkt* month year cm* cur* pt price um_name source price_kg 
	gsort adm0_name mkt_id cm_id -year -month
	label data "GIEWS and VAM food prices"
	
	tempfile data_all
	save `data_all'	

*** keep only country RMPB is interested in, and merge all data to master list
	import excel $path\input\country.xlsx, cellrange(A1) firstrow clear
	merge 1:m adm0_id using `data_all'
	drop if _merge==2 // drop countries RMPB is not interested in 
	gen Notes="no price data available" if _merge==1
	drop _merge
	
*** drop observation older than 20 years as "Over such a long period the underlying data generating process may change, 
* determining changes also in the components and in the components structure" (Source: Eurostat (2015), ESS guidelines on seasonal adjustment)
	drop if time<td(1, 6, 1996)  /* DATE TO BE CHANGED FOR NEXT UPDATE */

*** drop more recent and, thus more likely incomplete months because only few prices have been uploaded, thus the minum calorie for the
*	bood basked may be too low 
	keep if time<td(1, 7, 2016) | Notes!=""  /* DATE TO BE CHANGED FOR NEXT UPDATE */

*** drop non-food commodities		
	drop if regexm(cm_name, "Fuel") == 1
	drop if regexm(cm_name, "Livestock") == 1
	drop if regexm(cm_name, "Exchange") == 1
	drop if regexm(cm_name, "Wage") == 1
	drop if regexm(cm_name, "Transport") == 1
	
*** convert all VAM prices to kg price
	merge m:m ext_data adm0_id cm_id pt um_name cur_id using $path\input\list_master, ///
	keepusing (cm_kcal_100g fao_fct_name um_factor_to_kg fao_fct_kcalshare)
	
	capture assert _merge!=1 | Notes=="no price data available"
	if _rc==0 {
	}
	else display as error "Some price series (_merge==1) are not in the BigTable. Update the excel file and then run 03_cleaning.do"
	assert _merge!=1 | Notes=="no price data available"	
	keep if _merge ==3 | Notes!=""
	drop if fao_fct_kcalshare==0
	drop _merge
	gen price_kg_WFP = price / um_factor_to_kg if ext==0

*** check each group has the same currency
	egen group = group (adm0_id mkt_id cm_id pt)	
	egen tag=tag(group cur_id)
	bys gr: egen mul_cur=total(tag)
	capture assert mul_c<=1 | adm0_name=="Somalia"
	if _rc==0 {
	}
	else display as error "There are price series with different currency!"
	assert mul_c<=1 | adm0_name=="Somalia"
	drop tag mul 

*** convert all prices in Somalia in USD/kg
	merge m:1 adm0_name month year using $path\input\exch_rate_somalia
	drop if adm0_name=="Somalia"  & year<2012 // that's because we don't have the exchange rate
	drop if adm0_name=="Somalia"  & time>td(1, 6, 2016) // that's for months we don't have the exchange rate
	capture assert _merge!=1 if adm0_name=="Somalia"
		if _rc==0 {
		}
		else display as error "Exchange rate for Somalia are missing. Update the BigTable and run 02_cleaning.do"
		assert _merge!=1 if adm0_name=="Somalia"
	drop if _merge==2
	drop _m
	
	replace price_kg_WFP=price_kg_WFP/SoSh if adm0_name=="Somalia" & cur_id==79
	replace price_kg_WFP=price_kg_WFP/SlSh if adm0_name=="Somalia" & cur_id==81
	replace cur_name="USD" if adm0_name=="Somalia"
	replace cur_id=28 if adm0_name=="Somalia"

*** Egypt. Drop VAM price series because, series got interupted  by the use of a new source. 
    * When time series will be long enough, more recent data could instead be used
	drop if adm0_name=="Egypt" & ext==0  & time>=td(1, 10, 2015)
	
*** flag VAM and GIEWS series that are complementary, then choose the series with more values and complement with the other	
	replace mkt_id=9999999999 if adm0_name=="Algeria" & mkt_name=="National Average" & mkt_id==.	
	egen tag=tag(group ext)
	bys gr: egen complementary_series=total(tag)
		
	bys group: egen series_wfp=count(price_kg_WFP) if comp==2
	bys group: egen series_fao=count(price_kg_FAO) if comp==2
	
	gen price_kg_all=price_kg_WFP if comp==2 & series_wfp>=series_fao
	replace price_kg_all=price_kg_FAO if comp==2 & series_wfp<series_fao
	
	replace price_kg_all=price_kg_WFP if price_kg_all==. & price_kg_WFP!=.
	replace price_kg_all=price_kg_FAO if price_kg_all==. & price_kg_FAO!=.
	
	gen data_source="mainly WFP" if comp==2 & series_wfp>=series_fao
	replace data_source="mainly FAO" if comp==2 & series_wfp<series_fao
	
	keep year month time adm0_name adm0_id mkt_id mkt_name cm_id cm_name cm_name_FAO ///
	cur_id cur_name pt ext_data fao_fct_name fao_fct_kcalshare cm_kcal_100g price_kg_all data_source ext Notes

********************************	
*	generate national  price   *
********************************	
*** when both market-specific and national average prices exist, 
*	the ready-to-use national average series is preferred if:
*	1. it covers at least 5 years,
*	2. it has less than 30% data gaps
* 	3. it has at least one obs for each month
	egen series = group (adm0_id cm_id pt)	
	egen tag1=tag(series time) if mkt_name!="National Average" 
	egen tag2=tag(series time) if mkt_name=="National Average" 
	
	gen t=ym(year, month)
	qui forvalues n=1/2 {
		sort series time
		
		egen   date_start`n' = min(t) if tag`n', by (series)
		egen   date_end`n'   = max(t) if tag`n', by (series)
		format %tmMon-yy t date_start`n' date_end`n'
		gen 	month_cover`n' = date_end`n' - date_start`n' +1 if tag`n'
	
		bys series: egen data_count`n' = count(price) if tag`n'
		gen gap`n'=1-(data_count`n'/month_cover`n')
	
		forvalues j = 1/12 {
			gen d`j'_`n' = cond(month==`j', 1, 0) if tag`n'
		}
	
		forvalues j = 1/12{
			egen 	series_m`j'_`n' = max(d`j'_`n') if tag`n', by (series)
		}
		egen 	series_m`n'   = rowtotal(series_m*) if tag`n'
	
	}
	
	qui levelsof series if month_cover2>=60 & month_cover2!=. & gap2<.3 & series_m2==12, local (series) 
		qui foreach s of numlist `series'{
			drop if series==`s' & mkt_name!="National Average"
		}
	
	qui levelsof series if month_cover2<60 | gap2>=.3 | series_m2!=12, local (series)
		qui foreach s of numlist `series' {
			drop if series==`s' & mkt_name=="National Average"
		}

*** check that the currency is the same for each month, year, commodity, country combination (that's important for the calculation of the national average)
	egen tag =tag(month year cm_id adm0_id pt cur_id) if mkt_name!="National Average" 
	duplicates tag month year cm_id adm0_id pt tag if tag!=0 & mkt_name!="National Average" , gen (dup)
	capture assert dup==0 | dup==.  
		if _rc==0 {
		}
		else display as error "Different currency for the same price series across markets!"
		assert dup==0 | dup==.
	drop dup tag
	
*** generate national price
	bys series time: egen price=mean(price_kg_all) if mkt_name!="National Average"  
	replace price= price_kg_all if mkt_name=="National Average" & price==.
	label var price "national average price - local currency/kg"
	
	egen keep=tag(series time)
	keep if keep | Notes!=""
	
	replace data_source="WFP" if data_source=="" & ext==0
	replace data_source="FAO" if data_source=="" & ext==1
	gen national_price="computed" if mkt_name!="National Average"
	replace national_price="as in db" if mkt_name=="National Average"

*** check that the currency is the same in each country across time (that's important for the calculation of the cost of food basket)
	egen tag =tag(adm0_id cur_id)
	duplicates tag adm0_id tag if tag!=0 , gen (dup)
	capture assert dup==0 | dup==.  
			if _rc==0 {
		}
		else display as error "Different currency for the same country!"
		assert dup==0 | dup==.
	
	keep year month time adm0_name adm0_id cm_id cm_name cm_name_FAO cur_id cur_name pt refuse fao_fct_name fao_fct_kcalshare cm_kcal_100g series price data_source nationa Notes

*******************************	
*	Setting data requirment	  * 
*******************************
* keep only series with <30% missing values (missing + outliers)
	sort series t
	gen t=ym(year, month)
	egen   date_start = min(t), by (series)
	egen   date_end   = max(t), by (series)
	format %tmMon-yy date_start date_end
	gen 	month_cover = date_end - date_start +1
	bys series: egen data_count = count(price)
	drop if data_count/month_cover <.7	& Notes==""
	drop series
	egen series = group (adm0_id cm_id pt)	
	
*** keep only series cover > 5 years with a few exceptions
	gen exception=1 if month_cover>36 & (adm0_name=="Iran  (Islamic Republic of)" | adm0_name=="Sierra Leone" | adm0_name=="Somalia" | adm0_name=="Yemen")
	replace Notes="series shorter than 5 years"	if exception==1
	drop if month_cover <60	& Notes==""
		
*** keep only series cover all months 
	forvalues j = 1/12 {
	gen d`j' = cond(month==`j', 1, 0)
	}
	
	forvalues j = 1/12{
	egen 	series_m`j' = max(d`j'), by (series)
	}
	egen 	series_m   = rowtotal(series_m*)
	drop if series_m   <12 & Notes=="no price data available"
	drop series data_count date_start date_end month_cover	
		
*******************************	
*		OUTLIERS		  	  * 
*******************************
*** detect outliers 
	sort adm0_id cm_id pt
	egen series = group (adm0_id cm_id pt)	
	sort series time
	gen count=_n
	gen outlier=.

	gen lprice=log(price)

	sum series
	local max=r(max)
	forvalues i=1/`max' {
		qui sum count if  series==`i'
		local l=r(min)
		local u=r(max)
		forvalues d =`l'/`u' {
			qui sum lprice if series==`i' & count>=`d'-12 & count<=`d'+12 & count!=`d' & lprice!=., d
			replace outlier=1 if (series==`i' & count==`d'  & lprice>r(p50)+2*(r(p75)-r(p25)) & lprice!=.) | (series==`i' & count==`d' & lprice<r(p50)-2*(r(p75)-r(p25)) & lprice!=.)
		}
	}

* check that outliers are less than 10% in each series	(Source: Eurostat (2015), ESS guidelines on seasonal adjustment)
	bys series: egen outlier_count=count(outlier)
	bys series: egen data_count = count(price)
	gen perc_out=outlier_count/data_count
	drop if perc_out>.10 & Notes==""
	drop data_count
		
* set outlier as missing data
	gen price_original=price
	label var price_original "national average price w/o imputation"
	replace price=.	if outlier==1
	
* keep only series with <30% missing values (missing+outliers)
	egen   date_start = min(t), by (series)
	egen   date_end   = max(t), by (series)
	format %tmMon-yy date_start date_end
	gen 	month_cover = date_end - date_start +1
	bys series: egen data_count = count(price)
	drop if data_count/month_cover <.7	& Notes==""

********************************	
*	Setting  priority for      *
* price series within the same *
*      fao_fct_name	           * 
********************************
	do 03b_priority.do
	
*** by country, time and food group choose the commodity with the highest priority
	bys adm0_id fao_fct_name: egen high_priority=min(priority)
	keep if priority==high_priority

*******************************	
* impute missing and outliers *
*******************************
*** multiple imputation for missing and outliers
* set dataset as a panel dataset
	xtset series t
	tsfill  					
	bys series: replace adm0_id=adm0_id[_N] if Notes!="no price data available"
	bys series: replace adm0_name=adm0_name[_N] if Notes!="no price data available" & adm0_nam==""
	bys series: replace cm_name=cm_name[_N] if Notes!="no price data available" & cm_id==.
	bys series: replace cm_name_F=cm_name_F[_N] if Notes!="no price data available" & cm_id==.
	bys series: replace cm_id=cm_id[_N] if Notes!="no price data available"
	bys series: replace pt=pt[_N] if Notes!="no price data available"
	bys series: replace cur_id=cur_id[_N] 	if Notes!="no price data available"
	bys series: replace cur_name=cur_name[_N] 	if Notes!="no price data available"
	bys series: replace refuse=refuse[_N] if Notes!="no price data available"
	bys series: replace fao_fct_name=fao_fct_name[_N] if Notes!="no price data available"
	bys series: replace fao_fct_kcalshare=fao_fct_kcalshare[_N] if Notes!="no price data available"
	bys series: replace cm_kcal_100g=cm_kcal_100g[_N] if Notes!="no price data available" & cm_kcal_100g==.
	bys series: replace priority=priority[_N] if Notes!="no price data available"
	bys series: replace national_p=national_p[_N] if Notes!="no price data available" & national_p==""
	bys series: replace data_so=data_so[_N] if Notes!="no price data available" & data_so==""

* replace the missing price (either outliers or originally missing) using mi
	gen s1=sin(2*_pi*t/12)
	gen s2=cos(2*_pi*t/12)
	
	levelsof series if price==., local(series)
	qui foreach i of  numlist `series' {
		su price if series==`i' & price!=.
		local limitmin=r(min) 
		capture truncreg price t s1 s2 if series==`i', ll(`limitmin')
			if _rc==0 {
				reg price t s1 s2 if series==`i'
				predict p_hat_`i', xb
			}
			else {
				predict p_hat_`i', xb
			}
		replace price =p_hat_`i' if  series==`i' & price==.
	}
		

keep t time adm0_name adm0_id cur* pt fao_fct_name fao_fct_kcalshare cm_* pric* series priority national_p data_sour Notes

save $path/output/data_all_clean.dta, replace


