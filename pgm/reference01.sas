data cmrb;
	set icd;
	length cmrb $32.;
	*01. Cancer;
	IF 'C00' <= ICD10Code <= 'C3' OR 
		'C40' <= ICD10Code <= 'C5' OR
			ICD10Code in: ('C6') OR 
		'C70' <= ICD10Code <= 'C885' OR 
		ICD10Code= 'C883' OR 
		ICD10Code= 'C887' OR 
		ICD10Code= 'C889' OR 
		'C900' <= ICD10Code <= 'C9600' then
	 CMRB = "Cancer";

	*03. CardioVD;
		IF ICD10Code IN: ('I0981', 'I110', 'I200', 'I201', 'I208', 'I209', 'I2111', 
			'I2119', 'I2129', 'I213', 'I214', 'I240', 'I241', 'I248', 'I2510', 
			'I25810', 'I25811', 'I25812', 'I259', 'I501', 'I509', 'I5020', 'I5021', 
			'I5022', 'I5023', 'I5030', 'I5031', 'I5032', 'I5033', 'I5040', 'I5041', 'I5042', 
			'I5043', 'I509') THEN CMRB = "CardioVD";
	*04. Dementia;
		IF ICD10Code IN: ('F0150', 'F0151', 'F0280', 'F0281', 'F0390', 'F0391', 'F04', 'F05', 
			'F060', 'F068','G309', 'G3101', 'G3109', 'G311', 'G3183', 'G3184', 'G3185', 'G3189', 
			'G319', 'G910', 'G911', 'G912', 'G937', 'G94') THEN cmrb = 'Dementia';
	*05. Diabetes;
		IF ICD10Code IN: ('E10', 'E11', 'E12', 'E13', 'E14') THEN cmrb = "dm";
	
	*07. Chronic Lung Disease;
		IF ICD10Code IN: ('J41.', 'J411', 'J418', 'J42', 'J439', 'J440', 'J441', 
		'J449', 'J4520', 'J4521', 'J4522', 'J45901', 'J45902', 'J45909', 
		'J45990', 'J45991', 'J45998', 'J982', 'J983') THEN cmrb = 'CLD';

	IF cmrb="" then delete;
RUN;