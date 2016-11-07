/* -----------------------------------------------------------------------------

     WFP - Policy and Programme Division - Analysis & Trends Service 
		   Economic and Market Analysis Unit 
		   
     CONTACT: Lucia Latino 
			  lucia.latino@wfp.org
			  Latino@Economia.uniroma2.it
                    
	 AIM:  - get data for the estimation of the cost of food basket 
		from VAM server

----------------------------------------------------------------------------- */




*** Clear environment 
	clear
	set more off
	set maxvar 20000
	
********************************	
* get WFP data from the server *
********************************	

	set odbcdriver unicode
	odbc list
	global db  "DRIVER={SQL Server};SERVER=wfpromsqlp02;DATABASE=MONITORING;UID=monitor_usr_ro ;PWD=...;"
	
	odbc load, exec("SELECT * FROM grf_adminunits") conn("$db") clear
	rename ADM0_CODE ADM0_ID
	rename ADM0_NAME adm0_name
	duplicates drop ADM0_ID, force
	tempfile admin
	save `admin'
	
	local list_table markets commodities currencies pricetypes unitofmeasure vamreport monthlypriceitem
	foreach tl in `list_table' {
		local sql "SELECT * FROM `tl'"
		odbc load, exec("`sql'") conn("$db") clear
		tempfile `tl'
		save ``tl'', replace
	}

	merge m:m ADM0_ID using `admin', keepusing(adm0_name)
	assert _merge!=1
	keep if _merge==3
	drop _merge

	merge m:1 ADM0_ID mkt_id using `markets', keepusing(mkt_name)
	assert _merge!=1 | adm0_name=="Nicaragua"  /* in 2011-12 prices for few market are reported, but the name of the markets is unknown. Markets are droppped */
	keep if _merge==3
	drop _merge

	rename ADM0_ID adm0_id
	merge m:1 cm_id using `commodities', keepusing(cm_name)
	assert _merge!=1
	keep if _merge==3
	drop _merge

	merge m:1 cur_id using `currencies', keepusing(cur_name)
	assert _merge!=1
	keep if _merge==3
	drop _merge

	merge m:1 pt_id using `pricetypes', keepusing(pt_name)
	assert _merge!=1
	keep if _merge==3
	drop _merge
	labmask pt_id, values (pt_name) lblname(pt)
	rename pt_id pt
	drop pt_name

	merge m:1 um_id using `unitofmeasure', keepusing(um_name)
	assert _merge!=1
	keep if _merge==3
	drop _merge
	labmask um_id, values (um_name) lblname(unit)

	merge m:1 mr_id using `vamreport', keepusing(mr_status)
	assert _merge!=1
	keep if _merge==3
	drop _merge

	local today=c(current_date)
	label data "VAM Food Price database as at `today'"
	
	qui compress
	save $path/input/data_db.dta, replace
	
*** organize wfp data	
	rename mp_month month
	rename mp_year year
	rename mp_price price
	label var price "monthly price (nominal local currency/unit)"
	rename mp_commoditySource source
	label var source "original price data source"
	label var adm0_id "country code"
	label var adm0_name "country name"
	label var cm_id "commodity code"
	label var cm_name "commodity name"
	label var cur_id "currency code"
	label var cur_name "currency name"
	label var pt "price type"
	label var um_id "unit of measure - code"
	label var um_name "unit of measure - name"
		
	gen time = mdy(month, 1, year)
	format time %tdMon-YY
	gen t=ym(year, month)

* ad hoc fixies
	replace cur_name="Somaliland Shilling" if mkt_name=="Berbera" | ///
					mkt_name=="Borama" | mkt_name=="Burco" | mkt_name=="Hargeysa" | mkt_name=="Ceerigaabo" /* usually this change is performed in the DB */
	replace cur_id=81 if mkt_name=="Berbera" | mkt_name=="Borama" | ///
						mkt_name=="Burco" | mkt_name=="Hargeysa" | mkt_name=="Ceerigaabo" /* usually this change is performed in the DB */

	replace cm_name="Maize" if cm_name=="Maize (white)" & adm0_id==180 // IT SHOULD BE CHANGED IN THE DB
	replace cm_id=51 if cm_id==67 & adm0_id==180 // IT SHOULD BE CHANGED IN THE DB
	replace cm_name="Potatoes" if adm0_id==57 & cm_name=="Potatoes (unica)"
	replace cm_id=83 if adm0_id==57 & cm_id==213	
	
	drop if price==0
	
* import data for Nicaragua from excel sheet prepared by Ilaria for 2010-2013 as currently it is not possibe to upload them in the db
	drop if adm0_name=="Nicaragua" & t<tm(2014, 1)
	tempfile db
	save `db'
	
	clear
	import excel using $path/input/Nicaragua_Price_Data_2010_2013.xlsx, firstr sheet("Prices")
	rename PriceinUSD Price

	gen adm0_name="Nicaragua"
	rename MarketName mkt_name
	rename Commodity cm_name
	gen month=1 if Month=="Jan"
	replace month=2 if Month=="Feb"
	replace month=3 if Month=="Mar"
	replace month=4 if Month=="Apr"
	replace month=5 if Month=="May"
	replace month=6 if Month=="Jun"
	replace month=7 if Month=="Jul"
	replace month=8 if Month=="Aug"
	replace month=9 if Month=="Sep"
	replace month=10 if Month=="Oct"
	replace month=11 if Month=="Nov"
	replace month=12 if Month=="Dec"
	rename Year year
	gen time = mdy(month, 1, year)
	format time %tdMon-YY
	gen t=ym(year, month)
	
	gen pt=14 if PriceType=="Wholesale"
	replace pt=15 if PriceType=="Retail"
	rename Price price
	rename Unit um_name
	rename Currency cur_name
	rename DataSource source
	
	keep mkt_name cm_name year price um_name cur_name source adm0_name month time pt t
	
	append using `db'
	
	replace adm0_id=180 if adm0_name=="Nicaragua" & adm0_id==.
	replace mkt_id=298 if adm0_id==180 & mkt_name=="National Average" & mkt_id==.
	replace mkt_id=1896 if adm0_id==180 & mkt_name=="National Average (excl. capital)" & mkt_id==.
	replace mkt_id=1895 if adm0_id==180 & mkt_name=="Managua" & mkt_id==.

	replace cm_name= "Beans (red)"  if cm_name=="Beans (Red)" & adm0_id==180
	replace cm_name= "Oil (vegetable)"  if cm_name=="Oil (Vegetable)" & adm0_id==180
	replace cm_name= "Rice (milled 80-20)"  if cm_name=="Rice (Milled 80-20)" & adm0_id==180
	
	replace cm_id=78 if cm_name=="Beans (red)" & cm_id==.
	replace cm_id=55 if cm_name=="Bread" & cm_id==.
	replace cm_id=181 if cm_name=="Cabbage" & cm_id==.
	replace cm_id=142 if cm_name=="Cheese (dry)" & cm_id==.
	replace cm_id=209 if cm_name=="Coffee (instant)" & cm_id==.
	replace cm_id=401 if cm_name=="Fish (fresh)" & cm_id==.
	replace cm_id=51 if cm_name=="Maize" & cm_id==.
	replace cm_id=141 if cm_name=="Meat (beef)" & cm_id==.
	replace cm_id=140 if cm_name=="Meat (pork)" & cm_id==.
	replace cm_id=96 if cm_name=="Oil (vegetable)" & cm_id==.
	replace cm_id=111 if cm_name=="Onions (white)" & cm_id==.
	replace cm_id=360 if cm_name=="Oranges" & cm_id==.
	replace cm_id=449 if cm_name=="Peppers (sweet)" & cm_id==.
	replace cm_id=147 if cm_name=="Plantains" & cm_id==.
	replace cm_id=83 if cm_name=="Potatoes" & cm_id==.
	replace cm_id=86 if cm_name=="Rice (milled 80-20)" & cm_id==.
	replace cm_id=185 if cm_name=="Salt" & cm_id==.
	replace cm_id=340 if cm_name=="Squashes" & cm_id==.
	replace cm_id=97 if cm_name=="Sugar" & cm_id==.
	replace cm_id=114 if cm_name=="Tomatoes" & cm_id==.
	replace cm_id=269 if cm_name=="Tortilla (maize)" & cm_id==.

	replace um_id=27 if um_name=="Gallon"  & um_id==.
	replace um_id=30 if um_name=="Pound" & um_id==.

	replace cur_id=28 if cur_name=="USD" & adm0_id==180 & cur_id==.

	drop if cm_name=="Fuel (Petrol-Gasoline)" | cm_name=="Fuel (Diesel)"

	replace mr_status=4 if adm0_id==180 & t<tm(2014, 1)

* eliminate duplicates
	duplicates tag adm0_id mkt_id cm_id month year pt, gen(dup)
	drop if dup==1 & cur_id==86 /* duplicates in Nicaragua. Drop if currency is NIO */
	duplicates tag adm0_id mkt_id cm_id month year pt, gen(dup2)
	assert dup2==0
	drop dup dup2
	
* drop price whose report has been rejecyed (mr_status: 0 = in Progress; 1 = First Edit; 2 = Second Edit; 3 = Pending; 4 = approved; 5 = rejected)
	drop if mr_status==5

	keep adm0* mkt* cm* cur* pt* um* time month year price source
	gen ext_data = 0
	order  adm0* mkt* month year cm* cur* pt price um* source
	gsort adm0_name mkt_id cm_id -year -month
	local today=c(current_date)
	label data "VAM Food Price database as at `today'"
	
	qui compress
	save $path/output/data_wfp.dta, replace

