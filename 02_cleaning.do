/* -----------------------------------------------------------------------------

     WFP - Policy and Programme Division - Analysis & Trends Service 
		   Economic and Market Analysis Unit 
		   
     CONTACT: Lucia Latino 
			  lucia.latino@wfp.org
			  Latino@Economia.uniroma2.it
      
	 AIM: convert Nicaragua and Somalia prices in USD, compute national average,
		set price series priority, set data requirements, detect and impute outliers
     
     This version: July 15, 2016

----------------------------------------------------------------------------- */


*** Clear environment 
	clear
	set more off
	
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

*** keep only country RMPB is interested in, and merge all data to master list
	import excel $path\input\country.xlsx, cellrange(A1) firstrow clear

	merge 1:m adm0_id using $path\output\data_all.dta
	
	tab country if _==1 // country with no price data
	drop if _merge==2 // drop countries RMPB is not interested in 
	
	gen Notes="no price data available" if _merge==1
	drop _merge
	
	drop if regexm(cm_name, "Fuel") == 1
	drop if regexm(cm_name, "Livestock") == 1
	drop if regexm(cm_name, "Exchange") == 1
	drop if regexm(cm_name, "Wage") == 1
	drop if regexm(cm_name, "Transport") == 1
	
	merge m:m ext_data adm0_id cm_id pt um_name cur_id using $path\input\list_master, ///
	keepusing (cm_kcal_100g fao_fct_name um_factor_to_kg fao_fct_kcalshare)
	
	capture assert _merge!=1 | Notes=="no price data available"

	if _rc==0 {
	}
	else display as error "Some price series (_merge==1) are not in the BigTable. Update the excel file and then run 02_cleaning.do"
	
	keep if _merge ==3 | Notes!=""
	drop if fao_fct_kcalshare==0
	drop _merge

*** convert all VAM prices to kg price
	gen price_kg_WFP = price / um_factor_to_kg if ext==0

*** check each group has the same currency
	drop if adm0_name=="Honduras" & ext==1
	egen group = group (adm0_id mkt_id cm_id pt)	
	egen tag=tag(group cur_id)
	bys gr: egen mul_cur=total(tag)
	
	capture assert mul_c<=1 | adm0_name=="Nicaragua" | adm0_name=="Somalia"
	if _rc==0 {
	}
	else display as error "There are price series with different currency!"
	
	drop tag mul 
	
	tempfile temp
	save `temp'

*** convert all prices in Nicaragua in USD/kg
* get the exchange rate from the database
	clear
	set odbcdriver ansi
	odbc list
	global db  "DRIVER={SQL Server};SERVER=wfpromsqlp02;DATABASE=MONITORING;UID=monitor_usr_ro ;PWD=M0n1R015;"
	
	odbc load, exec("SELECT * FROM EconomicData") conn("$db") clear
	keep if CountryISO3=="NIC"
	tempfile data
	save `data'

	odbc load, exec("SELECT * FROM EconomicIndicators") conn("$db") clear
	keep EconomicIndicatorName EconomicIndicatorId EconomicIndicatorFrequency
	merge 1:m EconomicIndicatorId using `data'
	keep if _merge==3 & EconomicIndicatorName=="Currency"
	drop _merge
	tempfile data1
	save `data1'
	
	odbc load, exec("SELECT * FROM EconomicIndicatorProperties") conn("$db") clear
	keep EconomicIndicatorId EIPUnit EIPDataSource CountryISO3
	merge m:m EconomicIndicatorId CountryISO3 using `data1'
	keep if _m==3
	
	gen t =dofc(EconomicDataDate)
	format t %tdMon-YY
	gen year=year(t)
	gen month=month(t)
	rename t time
	bys month year: egen USD=mean(EconomicDataValue)
	label var USD "exchange rate NIO per 1USD (monthly - avg period)"
	egen tag=tag(month year)
	keep if tag
	gen adm0_name="Nicaragua"
	keep time adm0_name year month USD

	merge 1:m adm0_name month year using `temp'
	drop if _merge==1
	drop _merge
	replace price_kg_WFP=price_kg_WFP/USD if adm0_name=="Nicaragua" & cur_id==86 & ext==0
	replace cur_name="USD" if adm0_name=="Nicaragua" & cur_id==86 & ext==0 & USD!=.
	replace cur_id=28 if adm0_name=="Nicaragua" & cur_id==86 & ext==0 & USD!=.
	
	replace price_kg_FAO=price_kg_FAO/USD if adm0_name=="Nicaragua" & cur_id==86 & ext==1
	replace cur_name="USD" if adm0_name=="Nicaragua" & cur_id==86 & ext==1 & USD!=.
	replace cur_id=28 if adm0_name=="Nicaragua" & cur_id==86 & ext==1 & USD!=.

*** convert all prices in Somalia in USD/kg
	merge m:1 adm0_name month year using $path\input\exch_rate_somalia
	drop if adm0_name=="Somalia"  & year<2012 // that's because we don't have the exchange rate
	drop if adm0_name=="Somalia"  & time>td(1, 6, 2016) // that's for months we don't have the exchange rate
	capture assert _merge!=1 if adm0_name=="Somalia"
		if _rc==0 {
		}
		else display as error "Exchange rate for Somalia are missing. Update the BigTable and run 02_cleaning.do"

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
	
	codebook group if complementary==2
	
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

*** check that the currency is the same for each month, year, commodity, country combination

	drop if mkt_name!="National Average" & adm0_name=="Nicaragua"

	egen tag =tag(month year cm_id adm0_id cur_id) if mkt_name!="National Average" 
	duplicates tag month year cm_id adm0_id tag if tag!=0 & mkt_name!="National Average" , gen (dup)

	capture assert dup==0 | dup==.  
		if _rc==0 {
		}
		else display as error "Different currency for the same price series acroos markets!"
	
	drop dup tag
	
*** generate national price
	egen series = group (adm0_id cm_id pt)	
	bys series time: egen price=mean(price_kg_all) if mkt_name!="National Average"  
	replace price= price_kg_all if mkt_name=="National Average" & price==.
	label var price "national average price - local currency/kg"

*** when both market-specific and national average prices exist, 
*	the ready-to-use national average series is preferred if:
*	1. it covers at least 3 years,
*	2. it has less than 30% data gaps
* 	3. it has at least one obs for each month
* Special case: Sri Lanka. Computed national price are complemented by ready-to-use-national-average to fill few gaps. 	
	
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
	
	qui levelsof series if month_cover2>=36 & month_cover2!=. & gap2<.3 & series_m2==12, local (series) 
		qui foreach s of numlist `series'{
			drop if series==`s' & mkt_name!="National Average" & adm0_name!="Sri Lanka"
		}
	
	qui levelsof series if month_cover2<36 | gap2>=.3 | series_m2!=12, local (series)
		qui foreach s of numlist `series' {
			drop if series==`s' & mkt_name=="National Average" & adm0_name!="Sri Lanka"
		}
	
	
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
		
	keep year month time adm0_name adm0_id cm_id cm_name cm_name_FAO cur_id cur_name pt fao_fct_name fao_fct_kcalshare cm_kcal_100g series price data_source nationa Notes

********************************	
*	Setting  priority for      *
* price series within the same *
*      fao_fct_name	           * 
********************************
	
*** set priority for price series within the same fao_fct_name 
	sort series time
	gen t=ym(year, month)
	egen   date_start = min(t), by (series)
	egen   date_end   = max(t), by (series)
	format %tmMon-yy t date_start date_end
	gen 	month_cover = date_end - date_start +1
	
	bys series: egen data_count = count(price) 
	gen gap=1-(data_count/month_cover)
	
	forvalues j = 1/12 {
	gen d`j' = cond(month==`j', 1, 0)
	}
	
	forvalues j = 1/12{
	egen 	series_m`j' = max(d`j'), by (series)
	}
	egen 	series_m   = rowtotal(series_m*)

	bys adm0_id fao_fct_name: egen longer=max(month_cover)
	bys adm0_id fao_fct_name: egen complete=min(gap)

	gen priority=.
	
** CRITERIA 1: the longest and more complete series	
	gen criteria=.
	gen pick=(month_cover==longer & month_cover>=36 & gap==complete & gap<=0.3 & series_m==12)	
	replace criteria=1 if pick==1
	egen flag=tag(adm0_id cm_id pt)
	bys adm0_id fao_fct_name: egen check=total(pick) if flag 
	bys adm0_id fao_fct_name: egen check_sum=total(pick)
	replace priority=1 if pick==1 // highest priority is for the longest and more complete series
	
	sum check  // when first criteria selects multiple series within the same food group, series are ranked from the cheapest to the most expensive
	local mul_series=r(max)
	if `mul_series'>1 {
		tempvar mean   
		bys series: egen `mean'=mean(price) if t>date_end-36
		bys series: egen mean=mean(`mean')
		bys adm0_id fao_fct_name: egen equal_p=mean(check) 
		sum equal_p
		local check=r(max)
		local i=2
	
		while `i'<=`check' {
			display `i'
			bys adm0_id fao_fct_name: egen expensive=max(mean) if priority==1 & equal_p==`i'

			replace priority=`i' if mean!=. & expensive!=. & mean==expensive & equal_p==`i'
		
			local g=`i'
			while `g'>2 {
				drop expensive
				bys adm0_id fao_fct_name: egen expensive=max(mean) if priority==1 & equal_p==`i'
				replace priority=`g'-1 if mean==expensive & equal_p==`i'
				local g=`g'-1
			}
			drop expensive	
			local i=`i'+1
		}
	}
	
	 // apply second criteria for the series not satisfy first criteria but belong to the same group of other series satisfing the first criteria
	replace pick=1 if check_sum!=0 & priority==. & (month_cover==longer & month_cover>=36 & gap<=0.3 & series_m==12)
	replace criteria=1 if check_sum!=0 & priority==. & (month_cover==longer & month_cover>=36 & gap<=0.3 & series_m==12)
	tempvar max_p
	bys adm0_id fao_fct_name: egen `max_p'=max(priority)
	bys adm0_id fao_fct_name: replace priority=`max_p'+1 if priority==. & check_sum!=0 & pick==1
	
	tempvar dup  // when second criteria selects multiple series within the same food group, series are ranked from the cheapest to the most expensive
	duplicates tag adm0_id fao_fct_name priority if pick==1 & flag==1, gen(`dup')
	bys adm0_id fao_fct_name: egen duplicates=mean(`dup') if criteria==2  & `dup'!=0
	sum `dup' 
	local mul_series=r(max)
	if `mul_series'>0 {
	
		sum priority if `dup'>0 & `dup'!=.
		local check=r(max)+`mul_series'
		local i=r(min)
	
		while `i'<=`check' {
		
			bys adm0_id fao_fct_name: egen cheap=min(mean) if priority==`i' & duplicates>0

			replace priority=`i'+1 if mean!=cheap & priority==`i' & duplicates>0
			
			drop cheap
			local i=`i'+1
		}	
			 
	}
	drop duplicates
	
	 // apply third criteria for the series not satisfy first or second criteria but belong to the same group of other series satisfing the first criteria
	replace pick=1 if check_sum!=0 & priority==. & (month_cover>=36 & gap<=0.3 & series_m==12)
	replace criteria=1 if check_sum!=0 & priority==. & (month_cover>=36 & gap<=0.3 & series_m==12)
	tempvar max_p
	bys adm0_id fao_fct_name: egen `max_p'=max(priority)
	bys adm0_id fao_fct_name: replace priority=`max_p'+1 if priority==. & check_sum!=0 & pick==1
	
	tempvar dup  // when third criteria selects multiple series within the same food group, series are ranked from the cheapest to the most expensive
	duplicates tag adm0_id fao_fct_name priority if pick==1 & flag==1, gen(`dup')
	bys adm0_id fao_fct_name: egen duplicates=mean(`dup') if criteria==2  & `dup'!=0
	sum `dup' 
	local mul_series=r(max)
	if `mul_series'>0 {
	
		sum priority if `dup'>0 & `dup'!=.
		local check=r(max)+`mul_series'
		local i=r(min)
	
		while `i'<=`check' {
		
			bys adm0_id fao_fct_name: egen cheap=min(mean) if priority==`i' & duplicates>0

			replace priority=`i'+1 if mean!=cheap & priority==`i' & duplicates>0
			
			drop cheap
			local i=`i'+1
		}	
			 
	}		
	drop duplicates
	
** CRITERIA 2: longest series	
	replace pick=1 if check_sum==0 & (month_cover==longer & month_cover>=36 & gap<=0.3 & series_m==12)
	replace criteria=2 if check_sum==0 & (month_cover==longer & month_cover>=36 & gap<=0.3 & series_m==12)
	drop chec* equal_p
	bys adm0_id fao_fct_name: egen check=total(pick) if flag 
	bys adm0_id fao_fct_name: egen check_sum=total(pick)
	replace priority=1 if pick==1 & priority==.

	sum check if criteria==2 // when second criteria selects multiple series within the same food group, series are ranked from the cheapest to the most expensive
	local mul_series=r(max)
	if `mul_series'>1 {
		bys adm0_id fao_fct_name: egen equal_p=mean(check) if criteria==2
		sum equal_p
		local check=r(max)
		local i=2
	
		while `i'<=`check' {
			display `i'
			bys adm0_id fao_fct_name: egen expensive=max(mean) if priority==1 & equal_p==`i'

			replace priority=`i' if mean!=. & expensive!=. & mean==expensive & equal_p==`i'
		
			local g=`i'
			while `g'>2 {
				drop expensive
				bys adm0_id fao_fct_name: egen expensive=max(mean) if priority==1 & equal_p==`i'
				replace priority=`g'-1 if mean==expensive & equal_p==`i'
				local g=`g'-1
			}
			drop expensive	
			local i=`i'+1
		}
	}
	
	 // apply third criteria for the series not satisfing second criteria but belong to the same group of other series satisfing the second criteria
	replace pick=1 if check_sum!=0 & priority==. & (month_cover>=36 & gap<=0.3 & series_m==12)
	replace criteria=2 if check_sum!=0 & priority==. & (month_cover>=36 & gap<=0.3 & series_m==12)
	tempvar max_p
	bys adm0_id fao_fct_name: egen `max_p'=max(priority) if criteria==2
	bys adm0_id fao_fct_name: replace priority=`max_p'+1 if priority==. & check_sum!=0 & pick==1 & criteria==2
	
	tempvar dup  // when third criteria selects multiple series within the same food group, series are ranked from the cheapest to the most expensive
	duplicates tag adm0_id fao_fct_name priority if pick==1 & flag==1 & criteria==2, gen(`dup')
	bys adm0_id fao_fct_name: egen duplicates=mean(`dup') if criteria==2  & `dup'!=0
	sum `dup' 
	local mul_series=r(max)
	if `mul_series'>0 {
	
		sum priority if `dup'>0 & `dup'!=.
		local check=r(max)+`mul_series'
		local i=r(min)
	
		while `i'<=`check' {
			bys adm0_id fao_fct_name: egen cheap=min(mean) if priority==`i' & duplicates>0 
			replace priority=`i'+1 if mean!=cheap & priority==`i' & duplicates>0 
			drop cheap
			local i=`i'+1
		}		 
	}		
	drop duplicates
	
** CRITERIA 3: meet the minimum data requiremts		
	replace pick=1 if check_sum==0 & (month_cover>=36 & gap<=0.3 & series_m==12)
	replace criteria=3 if check_sum==0 & (month_cover>=36 & gap<=0.3 & series_m==12)
	drop chec* equal_p
	bys adm0_id fao_fct_name: egen check=total(pick) if flag 
	replace priority=1 if pick==1 & priority==. 
				
				** the following 3 lines are important if there are not cases of criteria 3, otherwise the following loop will keep running
				sum criteria
				replace criteria=3 if r(max)==2 
				replace check=1 if criteria==3
				
	sum check if criteria==3 // when third criteria selects multiple series within the same food group, series are ranked from the cheapest to the most expensive
	local mul_series=r(max)
	if `mul_series'>1 {
		bys adm0_id fao_fct_name: egen equal_p=mean(check) if criteria==3
		sum equal_p
		local check=r(max)
		local i=2
	
		while `i'<=`check' {
			display `i'
			bys adm0_id fao_fct_name: egen expensive=max(mean) if priority==1 & equal_p==`i'

			replace priority=`i' if mean!=. & expensive!=. & mean==expensive & equal_p==`i'
		
			local g=`i'
			while `g'>2 {
				drop expensive
				bys adm0_id fao_fct_name: egen expensive=max(mean) if priority==1 & equal_p==`i'
				replace priority=`g'-1 if mean==expensive & equal_p==`i'
				local g=`g'-1
			}
			drop expensive	
			local i=`i'+1
		}
	}
	
	assert check!=0 | (gap<=0.3 & month_cover<36 & series_m==12) | (gap<=0.3 & month_cover<36 & series_m!=12) | ///
		(gap>0.3 & month_cover>=36 & series_m==12) | (gap>0.3 & month_cover>=36 & series_m!=12) | ///
		(gap>0.3 & month_cover<36 & series_m==12) | (gap>0.3 & month_cover<36 & series_m!=12) | (gap<=0.3 & month_cover>=36 & series_m!=12)	

		
	drop serie* d1-d12 date* data_count month_cover gap longer complete criteria pick flag mean check 
	
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

* check that outliers are less than 5% in each series	
	bys series: egen outlier_count=count(outlier)
	bys series: egen data_count = count(price)
	gen perc_out=outlier_count/data_count
	
	drop data_count
		
* set outlier as missing data
	gen price_original=price
	label var price_original "national average price w/o imputation"
	replace price=.	if outlier==1
	
*******************************	
*	Setting data requirment	  * 
*******************************

* keep only series with <30% missing values (missing + outliers)
	sort series t
	egen   date_start = min(t), by (series)
	egen   date_end   = max(t), by (series)
	format %tmMon-yy date_start date_end
	gen 	month_cover = date_end - date_start +1
	bys series: egen data_count = count(price)
	drop if data_count/month_cover <.7	& Notes==""
	drop series
	egen series = group (adm0_id cm_id pt)	
	
*** keep only series cover > 3 years
	drop if month_cover <36	& Notes==""

		
*** keep only series cover all months 
	forvalues j = 1/12 {
	gen d`j' = cond(month==`j', 1, 0)
	}
	
	forvalues j = 1/12{
	egen 	series_m`j' = max(d`j'), by (series)
	}
	egen 	series_m   = rowtotal(series_m*)
	drop if series_m   <12 & Notes==""
	
	
*******************************	
* impute missing and outliers *
*******************************
*** multiple imputation for missing and outliers
* set dataset as a panel dataset
	xtset series t
	tsfill  					
	bys series: replace adm0_id=adm0_id[_N] if Notes==""
	bys series: replace adm0_name=adm0_name[_N]
	bys series: replace cm_id=cm_id[_N] 
	bys series: replace cm_name=cm_name[_N] 
	bys series: replace pt=pt[_N] 
	bys series: replace cur_id=cur_id[_N] 
	bys series: replace cur_name=cur_name[_N] 	
	bys series: replace fao_fct_name=fao_fct_name[_N] 
	bys series: replace fao_fct_kcalshare=fao_fct_kcalshare[_N] 
	bys series: replace cm_kcal_100g=cm_kcal_100g[_N] 
	bys series: replace priority=priority[_N] 
	bys series: replace cm_name=cm_name[_N] 
	bys series: replace cm_name_F=cm_name_F[_N] 
	bys series: replace national_p=national_p[_N] 
	bys series: replace data_so=data_so[_N] 

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


