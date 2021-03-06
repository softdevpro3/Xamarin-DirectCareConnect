USE [THPL]
GO
/****** Object:  StoredProcedure [dbo].[sp_StaffGetStaff]    Script Date: 10/2/2019 10:31:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[sp_StaffGetStaff]
@userprId INTEGER,
@prId INTEGER,
@userLevel VARCHAR(100)
AS
BEGIN
	DECLARE @staffLevel AS VARCHAR(100)
	DECLARE @accessGranted AS INT = 0

	/* See if we have access to targeted staff member*/
	IF @userLevel='SuperAdmin' OR  @userLevel='HumanResources' OR (@userprId = @prid)
		SET @accessGranted = 1
	ELSE
		WITH StaffList AS
		(SELECT S1.prid,1 AS eL
		FROM THPLipr AS S1
		WHERE prid=@userPrid
		UNION ALL
		SELECT S2.prid,SL.eL+1 AS eL
		FROM THPLipr AS S2
		INNER JOIN StaffList AS SL
		ON S2.supPrid=SL.prId OR S2.tempsupPrid=SL.prId
		WHERE S2.prid<>0 AND S2.prID IS NOT NULL)
		SELECT @accessGranted = COUNT(*)  FROM StaffList AS I WHERE prId=@prId AND prId<>@userPrid;

	
	IF @accessGranted <> 0
	BEGIN
		/* 0 Get Staff Data */
		SELECT S.prID,S.fn,S.ln,S.ln+' '+S.fn As nm,S.ad1,S.ad2,S.cty,S.st,S.z,S.ph,S.cl,S.em,S.eid,S.deleted,ISNULL(S.mi,'')AS mi,ISNULL(S.classification,'')AS classification,
		ISNULL(S.employeetype,'')AS employeetype,S.providestransport,ISNULL(S.refOfficeId,'')AS refOfficeId,ISNULL(S.linkedSSN,'')AS linkedSSN,ISNULL(S.ownVehicle,'')AS ownVehicle,ISNULL(S.irExemption,'')AS irExemption,S.profLicReq,S.profLiabilityReq,S.ahcccsId,S.npi,S.hiredtf,S.dobf,S.ttlf,S.ssnf,S.CRverf,S.termdt,ISNULL(S.Sex,'')AS Sex,ISNULL(S.npi,'')AS npi,S.providerHome,ISNULL(S.refOfficeId,'')AS refOfficeId,S.isSalary,S.PTFP,ISNULL(S.registered,0) AS registered,ISNULL(S.prt,0)AS prt,ISNULL(P.prDeptId,0) AS prDeptId,ISNULL(P.prDeptCode,'')AS prdeptCode,
		ISNULL(I2.prid,0) AS supId,I2.ln+' '+I2.fn AS supName,R2.roleId AS supRoleId,R2.roleName AS supRoleName,
		ISNULL(I3.prid,0) AS tempsupId,I3.ln+' '+I3.fn AS tempsupName,R3.roleId AS tempsupRoleId,R3.roleName AS tempsupRoleName 
		FROM THPLipr AS S
		LEFT JOIN PayrollDepts AS P ON P.prDeptId=S.prDeptId
		LEFT JOIN THPLipr AS I2 ON I2.prid=S.supPrId
		LEFT JOIN StaffRoles AS R2 ON R2.roleId=I2.isDirector OR R2.roleId=I2.isAssistantDirector OR  R2.roleId=I2.isSupervisor
		LEFT JOIN THPLipr AS I3 ON I3.prid=S.tempsupPrid
		LEFT JOIN StaffRoles AS R3 ON R3.roleId=I3.isDirector OR R2.roleId=I3.isAssistantDirector OR  R2.roleId=I3.isSupervisor

		WHERE S.prId=@prId
		
		/* 1 NOT SURE */
		SELECT TOP 0 NULL AS x

		/* 2 Comment History */
		SELECT CO.*,S.fn+' '+S.ln AS commentator
		FROM StaffComments AS CO
		JOIN THPLipr AS S ON S.prId=CO.commentatorId
		WHERE CO.prId=@prId
		ORDER BY commentId DESC

		/* 3 Credentials */
		SELECT *,
		CASE 
			WHEN R<>1 THEN 'Superseded'
			WHEN verified=1 AND validTo > DATEADD(DAY,30, GETDATE()) THEN 'Verified'
			WHEN verified=0 AND validTo > DATEADD(DAY,30, GETDATE()) THEN 'Not Verified'
			WHEN validTo < GETDATE() THEN 'Expired'
			WHEN validTo > DATEADD(DAY,-30, GETDATE()) THEN 'Expiring'
		ELSE 'Missing'
		END AS status,
		CASE 
			WHEN R<>1 THEN 6
			WHEN verified=1 AND validTo > DATEADD(DAY,30, GETDATE()) THEN 5
			WHEN verified=0 AND validTo > DATEADD(DAY,30, GETDATE()) THEN 4				
			WHEN validTo < GETDATE() THEN 2
			WHEN validTo > DATEADD(DAY,-30, GETDATE()) THEN 3
			WHEN validTo IS NULL THEN 1
		END AS priority
		FROM(
			SELECT A.*,ROW_NUMBER() OVER(PARTITION BY credTypeId ORDER BY verified ASC,validTo DESC)AS R 
			FROM
				(
				SELECT ICI.credName,ICI.credTypeId,IC.credId,IC.docId,IC.validFrom,IC.validTo,IC.verified,IC.verificationDate,IC.fileExtension,I2.fn,I2.ln			
				FROM THPLipr AS S
				JOIN CredentialIds AS ICI ON
				(S.isSuperAdmin<>0 AND ICI.superadmin<>0)OR
				(S.isHumanResources<>0 AND ICI.humanResources<>0)OR
				(S.isDirector<>0 AND ICI.director<>0)OR
				(S.isAssistantDirector<>0 AND ICI.assistantdirector<>0)OR
				(S.isSupervisor<>0 AND ICI.supervisor<>0)OR
				(S.isProvider<>0 AND ICI.provider<>0)OR
				(S.profLicReq<>0 AND ICI.credTypeId=7)OR
				(S.profLiabilityReq<>0 AND ICI.credTypeId=8)OR
				(S.providesTransport='Y' AND ICI.credTypeId=9)OR
				(S.ownVehicle='Y' AND (ICI.credTypeId=10 OR ICI.credTypeId=11))
				LEFT JOIN StaffCredentials AS IC ON IC.prId=S.prId AND IC.credTypeId=ICI.credTypeId
				LEFT JOIN THPLipr AS I2 ON I2.prid=IC.verifier
				WHERE S.prid=@prid
				)AS A
			) AS B
		ORDER BY priority asc,credname ASC, validTo ASC;

		/* 4 Client List */
		SELECT C.fn,C.ln,CI.relId,CI.clsvId,CI.pridr,AR.atcRelationship
        FROM ClientStaffRelationships AS CI
        JOIN THPLcl AS C ON C.clsvId=CI.clsvid AND c.deleted=0
		JOIN AtcRelationships AS AR ON AR.atcRelId=CI.pridr
        WHERE CI.prId=@prId ORDER BY C.ln ASC,C.fn ASC


	END
	ELSE
	BEGIN
		SELECT TOP 0 NULL AS x;
		SELECT TOP 0 NULL AS x;
		SELECT TOP 0 NULL AS x;
		SELECT TOP 0 NULL AS x;
		SELECT TOP 0 NULL AS x;
	END



END