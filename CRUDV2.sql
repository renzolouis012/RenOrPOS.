CREATE DATABASE DINOPOLL;
GO

USE DINOPOLL;
GO


-- =====================================
-- 1. PATIENTS TABLE
-- =====================================

CREATE TABLE Patients(
    PatientID INT IDENTITY(1,1) PRIMARY KEY NOT NULL,
    PatientNo VARCHAR(50) UNIQUE NOT NULL,
    FullName VARCHAR(200) NOT NULL,
    BirthDate DATE NOT NULL,
    Sex VARCHAR(20) NOT NULL
        CHECK (Sex IN ('M', 'F', 'O')),
    ContactNo VARCHAR(20),
    PatientStatus VARCHAR(20) NOT NULL
        CHECK (PatientStatus IN ('ACTIVE', 'INACTIVE'))
);


-- =====================================
-- 2. DOCTORS TABLE
-- =====================================

CREATE TABLE Doctors(
    DoctorID INT IDENTITY(1,1) PRIMARY KEY NOT NULL,
    LicenseNo VARCHAR(50) UNIQUE NOT NULL,
    FullName VARCHAR(200) NOT NULL,
    Specialization VARCHAR(100) NOT NULL
);


-- =====================================
-- 3. APPOINTMENTS TABLE
-- =====================================

CREATE TABLE Appointments(
    AppointmentID INT IDENTITY(1,1) PRIMARY KEY NOT NULL,
    PatientID INT NOT NULL,
    DoctorID INT NOT NULL,
    AppointmentDateTime DATETIME NOT NULL,
    AppointmentStatus VARCHAR(20) NOT NULL
        CHECK (AppointmentStatus IN
        ('Scheduled', 'Completed', 'Cancelled', 'NotShow')),
    Notes VARCHAR(500),

    FOREIGN KEY (PatientID)
        REFERENCES Patients(PatientID),

    FOREIGN KEY (DoctorID)
        REFERENCES Doctors(DoctorID),

    UNIQUE (DoctorID, AppointmentDateTime)
);


-- =====================================
-- 4. SERVICES TABLE
-- =====================================

CREATE TABLE Services(
    ServiceID INT IDENTITY(1,1) PRIMARY KEY NOT NULL,
    ServiceCode VARCHAR(50) UNIQUE NOT NULL,
    ServiceName VARCHAR(200) NOT NULL,
    StandardFee DECIMAL(12,2) NOT NULL
        CHECK (StandardFee >= 0)
);


-- =====================================
-- 5. INVOICES TABLE
-- =====================================

CREATE TABLE Invoices(
    InvoiceID INT IDENTITY(1,1) PRIMARY KEY NOT NULL,
    AppointmentID INT UNIQUE NOT NULL,
    InvoiceDate DATETIME NOT NULL
        DEFAULT GETDATE(),
    TotalAmount DECIMAL(12,2) NOT NULL
        CHECK (TotalAmount >= 0),
    PaymentStatus VARCHAR(20) NOT NULL
        CHECK (PaymentStatus IN
        ('Unpaid', 'Partially Paid', 'Paid')),

    FOREIGN KEY (AppointmentID)
        REFERENCES Appointments(AppointmentID)
);


-- =====================================
-- 6. INVOICE LINES TABLE
-- =====================================

CREATE TABLE InvoiceLines(
    InvoiceLineID INT IDENTITY(1,1) PRIMARY KEY NOT NULL,
    InvoiceID INT NOT NULL,
    ServiceID INT NOT NULL,
    Quantity INT NOT NULL
        CHECK (Quantity > 0),
    UnitFee DECIMAL(12,2) NOT NULL
        CHECK (UnitFee >= 0),

    LineAmount AS (Quantity * UnitFee) PERSISTED,

    FOREIGN KEY (InvoiceID)
        REFERENCES Invoices(InvoiceID),

    FOREIGN KEY (ServiceID)
        REFERENCES Services(ServiceID)
);
GO


USE DINOPOLL;
GO

CREATE PROCEDURE usp_Patient_Save
    @PatientNo VARCHAR(50),
    @FullName VARCHAR(200),
    @BirthDate DATE,
    @Sex VARCHAR(20),
    @ContactNo VARCHAR(20),
    @PatientStatus VARCHAR(20)
AS
BEGIN
    INSERT INTO Patients
    (PatientNo, FullName, BirthDate, Sex, ContactNo, PatientStatus)
    VALUES
    (@PatientNo, @FullName, @BirthDate,
     @Sex, @ContactNo, @PatientStatus);
END;
GO


CREATE PROCEDURE usp_Patient_View
AS
BEGIN
    SELECT * FROM Patients;
END;
GO


CREATE PROCEDURE usp_Patient_Update
    @PatientID INT,
    @PatientNo VARCHAR(50),
    @FullName VARCHAR(200),
    @BirthDate DATE,
    @Sex VARCHAR(20),
    @ContactNo VARCHAR(20),
    @PatientStatus VARCHAR(20)
AS
BEGIN
    UPDATE Patients
    SET PatientNo = @PatientNo,
        FullName = @FullName,
        BirthDate = @BirthDate,
        Sex = @Sex,
        ContactNo = @ContactNo,
        PatientStatus = @PatientStatus
    WHERE PatientID = @PatientID;
END;
GO


CREATE PROCEDURE usp_Patient_Delete
    @PatientID INT
AS
BEGIN
    DELETE FROM Patients
    WHERE PatientID = @PatientID;
END;
GO


CREATE PROCEDURE usp_Patient_Search
    @Search VARCHAR(200)
AS
BEGIN
    SELECT * FROM Patients
    WHERE FullName LIKE '%' + @Search + '%'
       OR PatientNo LIKE '%' + @Search + '%';
END;
GO

CREATE PROCEDURE usp_Doctor_Save
    @LicenseNo VARCHAR(50),
    @FullName VARCHAR(200),
    @Specialization VARCHAR(100)
AS
BEGIN
    INSERT INTO Doctors
    (LicenseNo, FullName, Specialization)
    VALUES
    (@LicenseNo, @FullName, @Specialization);
END;
GO


CREATE PROCEDURE usp_Doctor_View
AS
BEGIN
    SELECT * FROM Doctors;
END;
GO


CREATE PROCEDURE usp_Doctor_Update
    @DoctorID INT,
    @LicenseNo VARCHAR(50),
    @FullName VARCHAR(200),
    @Specialization VARCHAR(100)
AS
BEGIN
    UPDATE Doctors
    SET LicenseNo = @LicenseNo,
        FullName = @FullName,
        Specialization = @Specialization
    WHERE DoctorID = @DoctorID;
END;
GO


CREATE PROCEDURE usp_Doctor_Delete
    @DoctorID INT
AS
BEGIN
    DELETE FROM Doctors
    WHERE DoctorID = @DoctorID;
END;
GO


CREATE PROCEDURE usp_Service_Save
    @ServiceCode VARCHAR(50),
    @ServiceName VARCHAR(200),
    @StandardFee DECIMAL(12,2)
AS
BEGIN
    INSERT INTO Services
    (ServiceCode, ServiceName, StandardFee)
    VALUES
    (@ServiceCode, @ServiceName, @StandardFee);
END;
GO


CREATE PROCEDURE usp_Service_View
AS
BEGIN
    SELECT * FROM Services;
END;
GO


CREATE PROCEDURE usp_Service_Update
    @ServiceID INT,
    @ServiceCode VARCHAR(50),
    @ServiceName VARCHAR(200),
    @StandardFee DECIMAL(12,2)
AS
BEGIN
    UPDATE Services
    SET ServiceCode = @ServiceCode,
        ServiceName = @ServiceName,
        StandardFee = @StandardFee
    WHERE ServiceID = @ServiceID;
END;
GO


CREATE PROCEDURE usp_Service_Delete
    @ServiceID INT
AS
BEGIN
    DELETE FROM Services
    WHERE ServiceID = @ServiceID;
END;
GO



CREATE PROCEDURE usp_Appointment_Schedule
    @PatientID INT,
    @DoctorID INT,
    @AppointmentDateTime DATETIME,
    @Notes VARCHAR(500)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        IF NOT EXISTS (
            SELECT 1 FROM Patients WITH (UPDLOCK, HOLDLOCK)
            WHERE PatientID = @PatientID
              AND PatientStatus = 'ACTIVE'
        )
        BEGIN
            THROW 50001, 'Patient is inactive or does not exist.', 1;
        END

        IF NOT EXISTS (
            SELECT 1 FROM Doctors
            WHERE DoctorID = @DoctorID
        )
        BEGIN
            THROW 50002, 'Doctor does not exist.', 1;
        END

        IF EXISTS (
            SELECT 1 FROM Appointments WITH (UPDLOCK, HOLDLOCK)
            WHERE DoctorID = @DoctorID
              AND AppointmentDateTime = @AppointmentDateTime
        )
        BEGIN
            THROW 50003, 'Doctor already has an appointment at this time.', 1;
        END

        INSERT INTO Appointments
        (PatientID, DoctorID, AppointmentDateTime,
         AppointmentStatus, Notes)
        VALUES
        (@PatientID, @DoctorID, @AppointmentDateTime,
         'Scheduled', @Notes);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        THROW;
    END CATCH
END;
GO


CREATE PROCEDURE usp_Appointment_Cancel
    @AppointmentID INT
AS
BEGIN
    UPDATE Appointments
    SET AppointmentStatus = 'Cancelled'
    WHERE AppointmentID = @AppointmentID
      AND AppointmentStatus = 'Scheduled';

    IF @@ROWCOUNT = 0
        THROW 50004, 'Appointment cannot be cancelled.', 1;
END;
GO


CREATE PROCEDURE usp_Appointment_View
AS
BEGIN
    SELECT
        A.AppointmentID,
        P.FullName AS PatientName,
        D.FullName AS DoctorName,
        A.AppointmentDateTime,
        A.AppointmentStatus,
        A.Notes
    FROM Appointments A
    INNER JOIN Patients P
        ON A.PatientID = P.PatientID
    INNER JOIN Doctors D
        ON A.DoctorID = D.DoctorID;
END;
GO


CREATE TYPE InvoiceLineType AS TABLE(
    ServiceID INT,
    Quantity INT,
    UnitFee DECIMAL(12,2)
);
GO


CREATE PROCEDURE usp_Invoice_CreateWithLines
    @AppointmentID INT,
    @PaymentStatus VARCHAR(20),
    @Lines InvoiceLineType READONLY
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @InvoiceID INT;
    DECLARE @TotalAmount DECIMAL(12,2);

    BEGIN TRY
        BEGIN TRANSACTION;

        IF NOT EXISTS (
            SELECT 1 FROM Appointments WITH (UPDLOCK, HOLDLOCK)
            WHERE AppointmentID = @AppointmentID
              AND AppointmentStatus <> 'Cancelled'
        )
            THROW 50005, 'Invalid appointment.', 1;

        IF EXISTS (
            SELECT 1 FROM Invoices
            WHERE AppointmentID = @AppointmentID
        )
            THROW 50006, 'Invoice already exists.', 1;

        IF @PaymentStatus IS NULL
           OR @PaymentStatus NOT IN
              ('Unpaid', 'Partially Paid', 'Paid')
            THROW 50007, 'Invalid payment status.', 1;

        IF NOT EXISTS (SELECT 1 FROM @Lines)
            THROW 50008, 'Invoice lines are required.', 1;

        IF EXISTS (
            SELECT 1 FROM @Lines
            WHERE ServiceID IS NULL
               OR Quantity IS NULL
               OR UnitFee IS NULL
               OR Quantity <= 0
               OR UnitFee < 0
        )
            THROW 50009, 'Invalid invoice line.', 1;

        IF EXISTS (
            SELECT 1 FROM @Lines L
            WHERE NOT EXISTS (
                SELECT 1 FROM Services S
                WHERE S.ServiceID = L.ServiceID
            )
        )
            THROW 50010, 'Service does not exist.', 1;

        SELECT @TotalAmount =
            SUM(CAST(Quantity AS DECIMAL(18,2)) * UnitFee)
        FROM @Lines;

        IF @TotalAmount IS NULL
           OR @TotalAmount > 9999999999.99
            THROW 50011, 'Invalid invoice total.', 1;

        INSERT INTO Invoices
        (AppointmentID, TotalAmount, PaymentStatus)
        VALUES
        (@AppointmentID, @TotalAmount, @PaymentStatus);

        SET @InvoiceID = SCOPE_IDENTITY();

        INSERT INTO InvoiceLines
        (InvoiceID, ServiceID, Quantity, UnitFee)
        SELECT
            @InvoiceID, ServiceID, Quantity, UnitFee
        FROM @Lines;

        COMMIT TRANSACTION;

        SELECT @InvoiceID AS InvoiceID,
               @TotalAmount AS TotalAmount;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        THROW;
    END CATCH
END;
GO


CREATE PROCEDURE usp_Invoice_View
AS
BEGIN
    SELECT
        I.InvoiceID,
        I.AppointmentID,
        P.FullName AS PatientName,
        I.InvoiceDate,
        I.TotalAmount,
        I.PaymentStatus
    FROM Invoices I
    INNER JOIN Appointments A
        ON I.AppointmentID = A.AppointmentID
    INNER JOIN Patients P
        ON A.PatientID = P.PatientID;
END;
GO



USE DINOPOLL;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Service_Save
    @ServiceCode VARCHAR(50),
    @ServiceName VARCHAR(200),
    @StandardFee DECIMAL(12,2)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRANSACTION;

    BEGIN TRY
        DECLARE @NewServiceID INT;
        DECLARE @GeneratedCode VARCHAR(50);

        INSERT INTO dbo.Services
            (ServiceCode, ServiceName, StandardFee)
        VALUES
            ('TEMP-' + CONVERT(VARCHAR(36), NEWID()),
             @ServiceName, @StandardFee);

        SET @NewServiceID = SCOPE_IDENTITY();

        SET @GeneratedCode =
            'SERV-' +
            RIGHT('000' + CAST(@NewServiceID AS VARCHAR(20)),
                  CASE WHEN LEN(CAST(@NewServiceID AS VARCHAR(20))) > 3
                       THEN LEN(CAST(@NewServiceID AS VARCHAR(20)))
                       ELSE 3 END);

        UPDATE dbo.Services
        SET ServiceCode = @GeneratedCode
        WHERE ServiceID = @NewServiceID;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        THROW;
    END CATCH
END;
GO


USE DINOPOLL;
GO
S
SELECT
    cc.name AS ConstraintName,
    cc.definition AS ConstraintDefinition
FROM sys.check_constraints cc
WHERE cc.parent_object_id =
    OBJECT_ID('dbo.Invoices');



USE DINOPOLL;
GO

SELECT
    name AS ConstraintName,
    OBJECT_DEFINITION(object_id) AS FullDefinition
FROM sys.check_constraints
WHERE parent_object_id = OBJECT_ID('dbo.Invoices')
AND definition LIKE '%PaymentStatus%';