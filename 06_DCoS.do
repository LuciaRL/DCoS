/* -----------------------------------------------------------------------------

     WFP - Policy and Programme Division - Analysis & Trends Service 
		   Economic and Market Analysis Unit 
		   
     CONTACT: Lucia Latino 
			  lucia.latino@wfp.org
			  Latino@Economia.uniroma2.it
      
	 AIM: compute The Dietary Cost Score (DCoS) and the
			Dietary Cost Severity Score (DCoS)
     
     This version: August 26, 2016

----------------------------------------------------------------------------- */

	clear
	set more off
	
	use  $path/output/gsi.dta
	
	
*** get the monthly score	

	sum gsi
	gen windth=(r(max)-1)/4 // define the windth for the DCoS classes

	gen DCoS=.
	replace DCoS=1 if gsi<=1 & gsi!=.
	replace DCoS=2 if gsi>1 & gsi<=1+windth & gsi!=.
	replace DCoS=3 if gsi>1+windth & gsi<=1+2*windth & gsi!=.
	replace DCoS=4 if gsi>1+2*windth & gsi<=1+3*windth & gsi!=.
	replace DCoS=5 if gsi>1+3*windth & gsi<=1+4*windth & gsi!=.
		
*** get the monthly forward-looking indicator: Dietary Cost Severity Score (DCoS) in the coming six months 
	xtset adm0_id month
	
	gen gap=(DCoS-1)^2
	
	bys adm0_id: gen SG_DCoS=(F1.gap + F2.gap + F3.gap + F4.gap + F5.gap + F6.gap)/6
	bys adm0_id: replace SG_DCoS=(F1.gap + F2.gap + F3.gap + F4.gap + F5.gap + L6.gap)/6 if month==7
	bys adm0_id: replace SG_DCoS=(F1.gap + F2.gap + F3.gap + F4.gap + L6.gap + L7.gap)/6 if month==8
	bys adm0_id: replace SG_DCoS=(F1.gap + F2.gap + F3.gap + L6.gap + L7.gap + L8.gap)/6 if month==9
	bys adm0_id: replace SG_DCoS=(F1.gap + F2.gap + L6.gap + L7.gap + L8.gap + L9.gap)/6 if month==10
	bys adm0_id: replace SG_DCoS=(F1.gap + L6.gap + L7.gap + L8.gap + L9.gap + L10.gap)/6 if month==11
	bys adm0_id: replace SG_DCoS=(L6.gap + L7.gap + L8.gap + L9.gap + L10.gap + L11.gap)/6 if month==12

	sum SG_DCoS
	gen windth2=r(max)/4 // define the windth of the classes

	gen DCoS2=.
	replace DCoS2=1 if SG_DCoS==0
	replace DCoS2=2 if SG_DCoS>0 & SG_DCoS<=windth2 & SG_DCoS!=.
	replace DCoS2=3 if SG_DCoS>windth2 & SG_DCoS<=2*windth2 & SG_DCoS!=.
	replace DCoS2=4 if SG_DCoS>2*windth2 & SG_DCoS<=3*windth2 & SG_DCoS!=.
	replace DCoS2=5 if SG_DCoS>3*windth2 & SG_DCoS<=4*windth2 & SG_DCoS!=.

	keep adm0* month DCoS DCoS2 windth basket_kcal_share Notes last_d gsi
	
	gen  Month="Jan" if month==1 
	replace  Month="Feb" if  month==2
	replace Month="Mar" if month==3 
	replace  Month="Apr" if month==4
	replace  Month="May" if month==5
	replace Month="Jun" if month==6 
	replace Month="Jul" if month==7 
	replace  Month="Aug" if month==8
	replace Month="Sep" if month==9 
	replace  Month="Oct" if month==10
	replace  Month="Nov" if month==11
	replace  Month="Dec" if month==12

	tempfile temp
	save `temp'
	
	import excel $path\input\country.xlsx, cellrange(A1) firstrow clear
	
	merge 1:m adm0_id using `temp'

*** export scores in excel for the tableau visualization
preserve	
	sort adm0_id
	keep adm0_id adm0_name country Notes basket_kcal_share last_data month Month DCoS DCoS2 gsi
	export excel using "C:\Users\lucia.latino\Documents\2.Market_team\DCoS\tableau\tableau.xlsx", sheet("indicator") sheetreplace firstrow(varia)
restore	
*** export scores in excel for the annex
preserve
	drop DCoS2 month adm0_* _merg
	replace Month="Jan" if Month==""
	reshape wide DCoS, i(country) j(Month) s
	
	rename DCoS* *
	rename country Country

	replace Notes="data requirements not met" if Jan==. & Notes==""
	replace Notes="food basket accounts only for 30-40% of daily caloric intake" if basket_kcal_share<40 & Jan!=. & Notes==""
	replace Notes="food basket accounts only for 20-30% of daily caloric intake" if basket_kcal_share<30 & Jan!=. & Notes==""
	replace Notes="food basket accounts only for 10-20% of daily caloric intake" if basket_kcal_share<20 & Jan!=. & Notes==""
	replace Notes="food basket accounts only for 5-10% of daily caloric intake" if basket_kcal_share<10 & Jan!=. & Notes==""
	replace Notes="food basket accounts only for less than 5% of caloric intake" if basket_kcal_share<5 & Jan!=. & Notes==""
	replace Notes="food basket accounts only for 30-40% of daily caloric intake and series shorter than 5 years" if basket_kcal_share<40 & Jan!=. & Notes=="series shorter than 5 years"
	replace Notes="food basket accounts only for 20-30% of daily caloric intake and series shorter than 5 years" if basket_kcal_share<30 & Jan!=. & Notes=="series shorter than 5 years"
	replace Notes="food basket accounts only for 10-20% of daily caloric intake and series shorter than 5 years" if basket_kcal_share<20 & Jan!=. & Notes=="series shorter than 5 years"
	replace Notes="food basket accounts only for 5-10% of daily caloric intake and series shorter than 5 years" if basket_kcal_share<10 & Jan!=. & Notes=="series shorter than 5 years"
	replace Notes="food basket accounts only for less than 5% of caloric intake and series shorter than 5 years" if basket_kcal_share<5 & Jan!=. & Notes=="series shorter than 5 years"

	drop basket_kcal_share
	
	order Country Jan Fe Mar Ap May Jun Jul Au S O Nov D Not

	export excel Country Jan-Dec Notes using $path/output/DCoS.xlsx, sheet("DCoS") sheetreplace firstrow(varia) cell(A7)
	putexcel set $path/output/DCoS.xlsx, sheet("annex II - DCoS") modify
	putexcel (A7:N7), bold hcenter vcenter font(Calibri, 11, darkblue) 
	putexcel (A7:A120), bold  font(Calibri, 11)	
	putexcel (N8:N120), font(Calibri, 8)
	putexcel (B8:M120), nformat(number)
	putexcel A1="WFP - VAM/Economic and Market Analysis Unit", bold  vcenter font(Calibri, 14, blue)
	putexcel A3="Dietary Cost Score", bold  vcenter font(Calibri, 11, darkblue)
	local today=c(current_date)
	local data=last_data[1]
	putexcel A4="last update: `today' --- last prices used are from `data'" , italic font(Calibri, 11)
	putexcel P11="DCoS", bold hcenter vcenter font(Calibri, 11, darkblue)
	putexcel p12=1
	putexcel p13=2
	putexcel p14=3
	putexcel p15=4
	putexcel p16=5
	putexcel q10="% change from the average cost of the food basket" , bold vcenter font(Calibri, 11, darkblue)
	putexcel q11="min" , bold hcenter vcenter font(Calibri, 11, darkblue)
	putexcel q13=0
	putexcel q14=windth*100
	putexcel q15=2*windth*100
	putexcel q16=3*windth*100
	putexcel r11="max" , bold hcenter vcenter font(Calibri, 11, darkblue)
	putexcel r12="equal or below the average"
	putexcel r13=windth*100
	putexcel r14=2*windth*100
	putexcel r15=3*windth*100
	putexcel r16=4*windth*100
	
restore

preserve
	drop DCoS month adm0_* _merg win* 
	replace Month="Jan" if Month==""
	reshape wide DCoS2, i(country) j(Month) s
	
	rename DCoS2* *
	order country Jan Fe Mar Ap May Jun Jul Au S O Nov D Not
	rename country Country

	replace Notes="data requirements not met" if Jan==. & Notes==""
	replace Notes="food basket accounts only for 30-40% of daily caloric intake" if basket_kcal_share<40 & Jan!=. & Notes==""
	replace Notes="food basket accounts only for 20-30% of daily caloric intake" if basket_kcal_share<30 & Jan!=. & Notes==""
	replace Notes="food basket accounts only for 10-20% of daily caloric intake" if basket_kcal_share<20 & Jan!=. & Notes==""
	replace Notes="food basket accounts only for 5-10% of daily caloric intake" if basket_kcal_share<10 & Jan!=. & Notes==""
	replace Notes="food basket accounts only for less than 5% of caloric intake" if basket_kcal_share<5 & Jan!=. & Notes==""
	replace Notes="food basket accounts only for 30-40% of daily caloric intake and series shorter than 5 years" if basket_kcal_share<40 & Jan!=. & Notes=="series shorter than 5 years"
	replace Notes="food basket accounts only for 20-30% of daily caloric intake and series shorter than 5 years" if basket_kcal_share<30 & Jan!=. & Notes=="series shorter than 5 years"
	replace Notes="food basket accounts only for 10-20% of daily caloric intake and series shorter than 5 years" if basket_kcal_share<20 & Jan!=. & Notes=="series shorter than 5 years"
	replace Notes="food basket accounts only for 5-10% of daily caloric intake and series shorter than 5 years" if basket_kcal_share<10 & Jan!=. & Notes=="series shorter than 5 years"
	replace Notes="food basket accounts only for less than 5% of caloric intake and series shorter than 5 years" if basket_kcal_share<5 & Jan!=. & Notes=="series shorter than 5 years"
	drop basket_kcal_share
	
	export excel Country Jan-Dec Notes using $path/output/DCoS.xlsx, sheet("DCoS2") sheetreplace firstrow(varia) cell(A7)
	putexcel set $path/output/DCoS.xlsx, sheet("annex III - DCoS2") modify
	putexcel (A7:N7), bold hcenter vcenter font(Calibri, 11, darkblue) 
	putexcel (A7:A120), bold  font(Calibri, 11)
	putexcel (N8:N120), font(Calibri, 8)
	putexcel (B8:M120), nformat(number)
	putexcel A1="WFP - VAM/Economic and Market Analysis Unit", bold  vcenter font(Calibri, 14, blue)
	putexcel A3="Dietary Cost Severety Score in the six upcoming months", bold  vcenter font(Calibri, 11, darkblue)
	putexcel A4="last update: `today' --- last prices used are from `data'" , italic font(Calibri, 11)

restore

save $path/output/DCoS.dta, replace
