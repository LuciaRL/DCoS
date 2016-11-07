/* -----------------------------------------------------------------------------

     WFP - Policy and Programme Division - Analysis & Trends Service 
		   Economic and Market Analysis Unit 
		   
     CONTACT: Lucia Latino 
			  lucia.latino@wfp.org
			  Latino@Economia.uniroma2.it
                    
		    
     AIM: compute the seasonal index of the cost of the food basket
	 
  
----------------------------------------------------------------------------- */


*** Clear environment 
	clear
	set more off
	
	use $path/output/basket.dta, replace

	egen data=max(t)
	gen last_data= string(data, "%tmMonth_ccyy")
	
***** Seasonal index based on monthly price - LOG CMA PROCEDURE (Ittig, 2004)
	gen month=month(time)
	gen year=year(time)
	egen date_start = min(t), by (adm0_id)
	egen date_end   = max(t), by (adm0_id)
	
	gen lprice=log(food_basket)

	gen ma1=.
	gen ma2=.
	gen cma=.
	gen ratio=.
	gen si=.
	gen gsi=.
	
	xtset adm0_id t
		
	levelsof adm0_id if Notes=="", local (country) 
	foreach c of numlist `country' {
		sort t
		tempvar ma1
		tempvar ma2
		tssmooth ma `ma1' = lprice if adm0_id==`c', window(6 1 5)
		replace ma1= `ma1' if adm0_id==`c'
		tssmooth ma `ma2' = lprice if adm0_id==`c', window(6 1 5)
		replace ma2= `ma2' if adm0_id==`c'
	
		sort adm0_id t
		replace cma=(ma1+F.ma2)/2 if adm0_id==`c'

		replace cma=. if adm0_id==`c' & t<=date_start+5 /* we don't compute the moving average if the lag are missing at the begining and end of a series */
		replace cma=. if adm0_id==`c' & t>date_end- 6

		replace ratio=lprice-cma if adm0_id==`c'

		tempvar si
		bys month: egen `si'=mean(ratio) if ratio!=. & adm0_id==`c'

		replace si=exp(`si') if adm0_id==`c'

		tempvar tag
		egen `tag'=tag(adm0_id month) if si!=. & adm0_id==`c'
		
		sum si if `tag' & adm0_id==`c'

		replace gsi=si/r(mean) if adm0_id==`c' & `tag'/* Adjusted GSI (i.e. normalized seasonal index) */

}
	
	drop lprice ma* cma ratio si
	
	tempvar gsi
	bys adm0_id month: egen `gsi'=mean(gsi)
	replace gsi=`gsi'
	
	egen keep=tag(adm0_id month)
	
	keep if keep | Notes!="no price data available"

	keep adm0_name adm0_id month gsi basket_kcal_share Notes last_data
	
	sort adm0_name month 
	
	save $path/output/gsi.dta, replace

	
