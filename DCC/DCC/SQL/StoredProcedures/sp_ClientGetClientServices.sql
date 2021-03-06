/****** Object:  StoredProcedure [dbo].[sp_ClientGetClientServices]    Script Date: 12/1/2020 8:51:18 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[sp_ClientGetClientServices]
@clsvID INTEGER
AS
BEGIN
	SET NOCOUNT ON
	
	--select *from Service s join ClientServices cs on cs.serviceid=s.ServiceId join Clients cl on cl.clsvID=cs.clsvID where 
	--s.IsActive=1 and cs.clsvID=@clsvID
	/*
	SELECT srv.name,srv.ServiceId,                         
 CASE WHEN requiresATCRelationship<>0 THEN ISNULL(ATCR.atcRelationship, '') ELSE '' END AS atcRelationship              
 FROM ClientStaffRelationships AS CSR              
 JOIN CLientServices AS CS ON CS.id=CSR.clsvidId              
 JOIN Staff AS S ON S.prID=CSR.prid              
 JOIN CompanyServices AS CL ON CL.svc=CS.svc              
 LEFT JOIN ATCRelationships AS ATCR ON ATCR.atcRelId=CSR.atcRelId  join Service srv on srv.serviceid=cs.serviceid            
 WHERE CSR.clsvId=@clsvId              
 ORDER BY ln ASC, fn ASC, CS.svc ASC 
	*/

	SELECT srv.name, srv.serviceId
	FROM ClientServices cs
	JOIN CompanyServices srv ON srv.serviceId = cs.serviceid
	WHERE cs.clsvID = @clsvID
END