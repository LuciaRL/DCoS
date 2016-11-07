/* -----------------------------------------------------------------------------

     WFP - Policy and Programme Division - Analysis & Trends Service 
		   Economic and Market Analysis Unit 
		   
     CONTACT: Lucia Latino 
			  lucia.latino@wfp.org
			  Latino@Economia.uniroma2.it
      
	 AIM: compute The Seasonal Food Expenditure Score (SFE) and the
			Severity of the Seasonal Food Expenditure Score (SFES)
     
     This version: August 26, 2016

----------------------------------------------------------------------------- */

	clear
	set more off
	
	use  $path/output/gsi.dta
	
	
*** get the monthly score	

	sum gsi
	gen windth=(r(max)-1)/4 // define the windth for the SFE classes

	gen SFE=.
	replace SFE=1 if gsi<=1 & gsi!=.
	replace SFE=2 if gsi>1 & gsi<=1+windth & gsi!=.
	replace SFE=3 if gsi>1+windth & gsi<=1+2*windth & gsi!=.
	replace SFE=4 if gsi>1+2*windth & gsi<=1+3*windth & gsi!=.
	replace SFE=5 if gsi>1+3*windth & gsi<=1+4*windth & gsi!=.
		
*** get the monthly forward-looking indicator: Severity of the Seasonal Food Expenditure Score (SFES) in the coming six months 
	xtset adm0_id month
	
	gen gap=(SFE-1)^2
	
	bys adm0_id: gen SG_SFE=(F1.gap + F2.gap + F3.gap + F4.gap + F5.gap + F6.gap)/6
	bys adm0_id: replace SG_SFE=(F1.gap + F2.gap + F3.gap + F4.gap + F5.gap + L6.gap)/6 if month==7
	bys adm0_id: replace SG_SFE=(F1.gap + F2.gap + F3.gap + F4.gap + L6.gap + L7.gap)/6 if month==8
	bys adm0_id: replace SG_SFE=(F1.gap + F2.gap + F3.gap + L6.gap + L7.gap + L8.gap)/6 if month==9
	bys adm0_id: replace SG_SFE=(F1.gap + F2.gap + L6.gap + L7.gap + L8.gap + L9.gap)/6 if month==10
	bys adm0_id: replace SG_SFE=(F1.gap + L6.gap + L7.gap + L8.gap + L9.gap + L10.gap)/6 if month==11
	bys adm0_id: replace SG_SFE=(L6.gap + L7.gap + L8.gap + L9.gap + L10.gap + L11.gap)/6 if month==12

	sum SG_SFE
	gen windth2=r(max)/4 // define the windth of the classes

	gen SFES=.
	replace SFES=1 if SG_SFE==0
	replace SFES=2 if SG_SFE>0 & SG_SFE<=windth2 & SG_SFE!=.
	replace SFES=3 if SG_SFE>windth2 & SG_SFE<=2*windth2 & SG_SFE!=.
	replace SFES=4 if SG_SFE>2*windth2 & SG_SFE<=3*windth2 & SG_SFE!=.
	replace SFES=5 if SG_SFE>3*windth2 & SG_SFE<=4*windth2 & SG_SFE!=.

	keep adm0* month SFE SFES windth basket_kcal_share Notes last_d
	
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

*** export scores in excel 
preserve
	drop SFES month adm0_* _merg
	replace Month="Jan" if Month==""
	reshape wide SFE, i(country) j(Month) s
	
	rename SFE* *
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

	export excel Country Jan-Dec Notes using $path/output/SFE.xlsx, sheet("SFE") sheetreplace firstrow(varia) cell(A7)
	putexcel set $path/output/SFE.xlsx, sheet("SFE") modify
	putexcel (A7:N7), bold hcenter vcenter font(Calibri, 11, darkblue) 
	putexcel (A7:A120), bold  font(Calibri, 11)	
	putexcel (N8:N120), font(Calibri, 8)
	putexcel (B8:M120), nformat(number)
	putexcel A1="WFP - VAM/Economic and Market Analysis Unit", bold  vcenter font(Calibri, 14, blue)
	putexcel A2="Seasonal Food Expenditure Score", bold  vcenter font(Calibri, 11, darkblue)
	local today=c(current_date)
	local data=last_data[1]
	putexcel A3="last update: `today' --- last prices used are from `data'" , italic font(Calibri, 11)
	putexcel P11="SFE", bold hcenter vcenter font(Calibri, 11, darkblue)
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
	drop SFE month adm0_* _merg win* 
	replace Month="Jan" if Month==""
	reshape wide SFES, i(country) j(Month) s
	
	rename SFES* *
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
	
	export excel Country Jan-Dec Notes using $path/output/SFE.xlsx, sheet("SFES") sheetreplace firstrow(varia) cell(A7)
	putexcel set $path/output/SFE.xlsx, sheet("SFES") modify
	putexcel (A7:N7), bold hcenter vcenter font(Calibri, 11, darkblue) 
	putexcel (A7:A120), bold  font(Calibri, 11)
	putexcel (N8:N120), font(Calibri, 8)
	putexcel (B8:M120), nformat(number)
	putexcel A1="WFP - VAM/Economic and Market Analysis Unit", bold  vcenter font(Calibri, 14, blue)
	putexcel A2="Severety of Seasonal Food Expenditure Score in the six upcoming months", bold  vcenter font(Calibri, 11, darkblue)
	putexcel A3="last update: `today' --- last prices used are from `data'" , italic font(Calibri, 11)

restore

save $path/output/SFE.dta, replace
