--
-- PostgreSQL database dump
--

-- Dumped from database version 15.5
-- Dumped by pg_dump version 16.0

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: calculateandinsertpaymentwithfine(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.calculateandinsertpaymentwithfine() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    rental_duration INT;           -- Kiralama süresi
    late_days INT;                 -- Geç iade gün sayısı
    total_payment DECIMAL(10, 2);  -- Toplam ödeme
    fine_amount DECIMAL(10, 2);    -- Geç iade cezası
BEGIN
    -- Kiralama süresi hesaplanıyor (EndDate ve StartDate arasındaki fark)
    rental_duration := NEW.ReturnDate - NEW.StartDate;

    -- Geç iade gün sayısını hesaplıyoruz (ReturnDate - EndDate)
    IF NEW.ReturnDate IS NOT NULL AND NEW.ReturnDate > NEW.EndDate THEN
        late_days := NEW.ReturnDate - NEW.EndDate;
    ELSE
        late_days := 0;  -- Geç iade yoksa 0
    END IF;

    -- Araç fiyatı üzerinden toplam ödeme hesaplanıyor (günlük fiyat * kiralama süresi)
    total_payment := rental_duration * (SELECT PricePerDay FROM Vehicles WHERE VehicleID = NEW.VehicleID);

    -- Geç iade cezası hesaplanıyor (geç iade gün sayısı * ceza miktarı)
    fine_amount := late_days * 20.00;  -- Geç iade başına 20 birim ceza

    -- Toplam ödeme miktarı (ceza dahil) hesaplanıyor
    total_payment := total_payment + fine_amount;

    -- Payments tablosuna ödeme kaydı ekleniyor
    INSERT INTO Payments (RentalID, PaymentAmount, PaymentDate)
    VALUES (NEW.RentalID, total_payment, CURRENT_DATE);

    -- Eğer geç iade cezası varsa, Fines tablosuna ceza kaydı ekleniyor
    IF fine_amount > 0 THEN
        INSERT INTO Fines (RentalID, FineAmount, FineDate)
        VALUES (NEW.RentalID, fine_amount, CURRENT_DATE);
    END IF;

    -- Eğer araç geç iade edilmişse, RentalTransactions tablosundaki durumu 'Late' olarak güncelle
    IF fine_amount > 0 THEN
        UPDATE RentalTransactions
        SET Status = 'Late'
        WHERE RentalID = NEW.RentalID;
    END IF;

    RETURN NEW;
END;
$$;


ALTER FUNCTION public.calculateandinsertpaymentwithfine() OWNER TO postgres;

--
-- Name: setvehicleundermaintenance(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.setvehicleundermaintenance() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Eğer bakım tarihi bugüne eşitse, araç durumunu 'Under Maintenance' yap
    UPDATE Vehicles
    SET Status = 'Under Maintenance'
    WHERE VehicleID = NEW.VehicleID
      AND NEW.MaintenanceDate = CURRENT_DATE;

    RETURN NEW;
END;
$$;


ALTER FUNCTION public.setvehicleundermaintenance() OWNER TO postgres;

--
-- Name: updateaveragevehiclerating(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.updateaveragevehiclerating() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    avg_rating DECIMAL(3, 2);  -- Ortalama rating
BEGIN
    -- Araç için tüm yorumları alıp ortalama rating hesapla
    SELECT AVG(Rating) INTO avg_rating
    FROM VehicleReviews
    WHERE VehicleID = NEW.VehicleID;

    -- Vehicles tablosunda aracın ortalama rating değerini güncelle
    UPDATE Vehicles
    SET AverageRating = avg_rating
    WHERE VehicleID = NEW.VehicleID;

    RETURN NEW;
END;
$$;


ALTER FUNCTION public.updateaveragevehiclerating() OWNER TO postgres;

--
-- Name: updatevehiclestatus(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.updatevehiclestatus() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF TG_OP = 'INSERT' OR TG_OP = 'UPDATE' THEN
        IF NEW.ReturnDate IS NOT NULL THEN
            UPDATE Vehicles
            SET Status = 'Available'
            WHERE VehicleID = NEW.VehicleID;
        ELSIF NEW.Status = 'Active' THEN
            UPDATE Vehicles
            SET Status = 'Rented'
            WHERE VehicleID = NEW.VehicleID;
        END IF;
    END IF;
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.updatevehiclestatus() OWNER TO postgres;

--
-- Name: validateandsetreturnstatus(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.validateandsetreturnstatus() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        -- Araç kiralanırken kontrol: "Rented" veya "Under Maintenance" durumda olamaz
        IF (SELECT Status FROM Vehicles WHERE VehicleID = NEW.VehicleID) IN ('Rented', 'Under Maintenance') THEN
            RAISE EXCEPTION 'This vehicle is either already rented or under maintenance and cannot be rented.';
        END IF;

    ELSIF TG_OP = 'UPDATE' THEN
        -- Araç iade edilirken kontrol: "Rented" durumda olmalı
        IF NEW.ReturnDate IS NOT NULL THEN
            IF (SELECT Status FROM Vehicles WHERE VehicleID = NEW.VehicleID) != 'Rented' THEN
                RAISE EXCEPTION 'This vehicle is not currently rented and cannot be returned.';
            END IF;

            -- ReturnDate kullanıcı tarafından girilir, durum belirlenir
            IF NEW.ReturnDate <= NEW.EndDate THEN
                NEW.Status := 'Completed'; -- Zamanında iade
            ELSE
                NEW.Status := 'Late'; -- Geç iade
            END IF;
        END IF;
    END IF;

    RETURN NEW;
END;
$$;


ALTER FUNCTION public.validateandsetreturnstatus() OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: customers; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.customers (
    customerid integer NOT NULL,
    personid integer NOT NULL,
    registrationdate date NOT NULL
);


ALTER TABLE public.customers OWNER TO postgres;

--
-- Name: customers_customerid_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.customers_customerid_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.customers_customerid_seq OWNER TO postgres;

--
-- Name: customers_customerid_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.customers_customerid_seq OWNED BY public.customers.customerid;


--
-- Name: employee; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.employee (
    employeeid integer NOT NULL,
    personid integer NOT NULL,
    jobtitle character varying(100) NOT NULL,
    salary numeric(10,2) NOT NULL,
    hiredate date NOT NULL
);


ALTER TABLE public.employee OWNER TO postgres;

--
-- Name: employee_employeeid_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.employee_employeeid_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.employee_employeeid_seq OWNER TO postgres;

--
-- Name: employee_employeeid_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.employee_employeeid_seq OWNED BY public.employee.employeeid;


--
-- Name: fines; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.fines (
    fineid integer NOT NULL,
    rentalid integer NOT NULL,
    fineamount numeric(10,2) NOT NULL,
    finedate date DEFAULT CURRENT_DATE NOT NULL
);


ALTER TABLE public.fines OWNER TO postgres;

--
-- Name: fines_fineid_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.fines_fineid_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.fines_fineid_seq OWNER TO postgres;

--
-- Name: fines_fineid_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.fines_fineid_seq OWNED BY public.fines.fineid;


--
-- Name: maintenancerecords; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.maintenancerecords (
    maintenanceid integer NOT NULL,
    vehicleid integer NOT NULL,
    maintenancedate date NOT NULL,
    description text NOT NULL,
    cost numeric(10,2) NOT NULL
);


ALTER TABLE public.maintenancerecords OWNER TO postgres;

--
-- Name: maintenancerecords_maintenanceid_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.maintenancerecords_maintenanceid_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.maintenancerecords_maintenanceid_seq OWNER TO postgres;

--
-- Name: maintenancerecords_maintenanceid_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.maintenancerecords_maintenanceid_seq OWNED BY public.maintenancerecords.maintenanceid;


--
-- Name: payments; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.payments (
    paymentid integer NOT NULL,
    rentalid integer NOT NULL,
    paymentamount numeric(10,2) NOT NULL,
    paymentdate date DEFAULT CURRENT_DATE NOT NULL
);


ALTER TABLE public.payments OWNER TO postgres;

--
-- Name: payments_paymentid_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.payments_paymentid_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.payments_paymentid_seq OWNER TO postgres;

--
-- Name: payments_paymentid_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.payments_paymentid_seq OWNED BY public.payments.paymentid;


--
-- Name: person; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.person (
    personid integer NOT NULL,
    firstname character varying(100),
    lastname character varying(100),
    email character varying(100),
    phonenumber character varying(20),
    role character varying(20),
    CONSTRAINT person_role_check CHECK (((role)::text = ANY ((ARRAY['Customer'::character varying, 'Employee'::character varying])::text[])))
);


ALTER TABLE public.person OWNER TO postgres;

--
-- Name: person_personid_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.person_personid_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.person_personid_seq OWNER TO postgres;

--
-- Name: person_personid_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.person_personid_seq OWNED BY public.person.personid;


--
-- Name: rentaltransactions; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.rentaltransactions (
    rentalid integer NOT NULL,
    vehicleid integer NOT NULL,
    customerid integer NOT NULL,
    startdate date NOT NULL,
    enddate date NOT NULL,
    returndate date,
    status character varying(50) DEFAULT 'Active'::character varying NOT NULL,
    CONSTRAINT rentaltransactions_status_check CHECK (((status)::text = ANY ((ARRAY['Active'::character varying, 'Completed'::character varying, 'Late'::character varying])::text[])))
);


ALTER TABLE public.rentaltransactions OWNER TO postgres;

--
-- Name: rentaltransactions_rentalid_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.rentaltransactions_rentalid_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.rentaltransactions_rentalid_seq OWNER TO postgres;

--
-- Name: rentaltransactions_rentalid_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.rentaltransactions_rentalid_seq OWNED BY public.rentaltransactions.rentalid;


--
-- Name: vehiclecategories; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.vehiclecategories (
    categoryid integer NOT NULL,
    categoryname character varying(50) NOT NULL
);


ALTER TABLE public.vehiclecategories OWNER TO postgres;

--
-- Name: vehiclecategories_categoryid_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.vehiclecategories_categoryid_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.vehiclecategories_categoryid_seq OWNER TO postgres;

--
-- Name: vehiclecategories_categoryid_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.vehiclecategories_categoryid_seq OWNED BY public.vehiclecategories.categoryid;


--
-- Name: vehiclereviews; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.vehiclereviews (
    reviewid integer NOT NULL,
    vehicleid integer NOT NULL,
    customerid integer NOT NULL,
    reviewdate date DEFAULT CURRENT_DATE NOT NULL,
    rating integer NOT NULL,
    reviewtext text,
    CONSTRAINT vehiclereviews_rating_check CHECK (((rating >= 1) AND (rating <= 5)))
);


ALTER TABLE public.vehiclereviews OWNER TO postgres;

--
-- Name: vehiclereviews_reviewid_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.vehiclereviews_reviewid_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.vehiclereviews_reviewid_seq OWNER TO postgres;

--
-- Name: vehiclereviews_reviewid_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.vehiclereviews_reviewid_seq OWNED BY public.vehiclereviews.reviewid;


--
-- Name: vehicles; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.vehicles (
    vehicleid integer NOT NULL,
    make character varying(100) NOT NULL,
    model character varying(100) NOT NULL,
    year integer NOT NULL,
    priceperday numeric(10,2) NOT NULL,
    status character varying(50) DEFAULT 'Available'::character varying NOT NULL,
    categoryid integer NOT NULL,
    averagerating numeric(3,2),
    CONSTRAINT vehicles_status_check CHECK (((status)::text = ANY ((ARRAY['Available'::character varying, 'Rented'::character varying, 'Under Maintenance'::character varying])::text[]))),
    CONSTRAINT vehicles_year_check CHECK (((year >= 1900) AND ((year)::numeric <= EXTRACT(year FROM CURRENT_DATE))))
);


ALTER TABLE public.vehicles OWNER TO postgres;

--
-- Name: vehicles_vehicleid_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.vehicles_vehicleid_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.vehicles_vehicleid_seq OWNER TO postgres;

--
-- Name: vehicles_vehicleid_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.vehicles_vehicleid_seq OWNED BY public.vehicles.vehicleid;


--
-- Name: customers customerid; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.customers ALTER COLUMN customerid SET DEFAULT nextval('public.customers_customerid_seq'::regclass);


--
-- Name: employee employeeid; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.employee ALTER COLUMN employeeid SET DEFAULT nextval('public.employee_employeeid_seq'::regclass);


--
-- Name: fines fineid; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.fines ALTER COLUMN fineid SET DEFAULT nextval('public.fines_fineid_seq'::regclass);


--
-- Name: maintenancerecords maintenanceid; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.maintenancerecords ALTER COLUMN maintenanceid SET DEFAULT nextval('public.maintenancerecords_maintenanceid_seq'::regclass);


--
-- Name: payments paymentid; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.payments ALTER COLUMN paymentid SET DEFAULT nextval('public.payments_paymentid_seq'::regclass);


--
-- Name: person personid; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.person ALTER COLUMN personid SET DEFAULT nextval('public.person_personid_seq'::regclass);


--
-- Name: rentaltransactions rentalid; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.rentaltransactions ALTER COLUMN rentalid SET DEFAULT nextval('public.rentaltransactions_rentalid_seq'::regclass);


--
-- Name: vehiclecategories categoryid; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.vehiclecategories ALTER COLUMN categoryid SET DEFAULT nextval('public.vehiclecategories_categoryid_seq'::regclass);


--
-- Name: vehiclereviews reviewid; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.vehiclereviews ALTER COLUMN reviewid SET DEFAULT nextval('public.vehiclereviews_reviewid_seq'::regclass);


--
-- Name: vehicles vehicleid; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.vehicles ALTER COLUMN vehicleid SET DEFAULT nextval('public.vehicles_vehicleid_seq'::regclass);


--
-- Data for Name: customers; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO public.customers VALUES
	(1, 1, '2023-01-15'),
	(2, 2, '2023-03-22'),
	(3, 3, '2023-05-10');


--
-- Data for Name: employee; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO public.employee VALUES
	(1, 4, 'Manager', 50000.00, '2020-06-15'),
	(2, 5, 'Salesperson', 35000.00, '2021-02-20');


--
-- Data for Name: fines; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO public.fines VALUES
	(1, 3, 20.00, '2024-12-24');


--
-- Data for Name: maintenancerecords; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO public.maintenancerecords VALUES
	(1, 1, '2024-12-24', 'Routine check-up', 100.00),
	(2, 2, '2024-12-05', 'Brake pad replacement', 200.00),
	(3, 3, '2024-12-10', 'Engine diagnostic and tuning', 300.00),
	(4, 4, '2024-12-15', 'Transmission fluid replacement', 250.00),
	(5, 5, '2024-12-20', 'Battery replacement', 120.00);


--
-- Data for Name: payments; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO public.payments VALUES
	(1, 3, 740.00, '2024-12-24'),
	(2, 2, 220.00, '2024-12-24'),
	(3, 4, 0.00, '2024-12-25');


--
-- Data for Name: person; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO public.person VALUES
	(1, 'John', 'Doe', 'john.doe@example.com', '555-1234', 'Customer'),
	(2, 'Jane', 'Smith', 'jane.smith@example.com', '555-5678', 'Customer'),
	(3, 'Mark', 'Johnson', 'mark.johnson@example.com', '555-8765', 'Customer'),
	(4, 'Michael', 'Brown', 'michael.brown@company.com', '555-3456', 'Employee'),
	(5, 'Sarah', 'Davis', 'sarah.davis@company.com', '555-2345', 'Employee');


--
-- Data for Name: rentaltransactions; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO public.rentaltransactions VALUES
	(3, 3, 3, '2024-12-20', '2024-12-25', '2024-12-26', 'Late'),
	(2, 2, 2, '2024-12-20', '2024-12-24', '2024-12-24', 'Completed'),
	(4, 3, 3, '2024-12-25', '2024-12-27', '2024-12-25', 'Completed');


--
-- Data for Name: vehiclecategories; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO public.vehiclecategories VALUES
	(1, 'Sedan'),
	(2, 'SUV'),
	(3, 'Hatchback'),
	(4, 'Convertible');


--
-- Data for Name: vehiclereviews; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO public.vehiclereviews VALUES
	(1, 2, 1, '2024-12-24', 5, 'Great car! Very comfortable and smooth to drive.'),
	(2, 2, 2, '2024-12-24', 4, 'Good car, but could use better fuel efficiency.');


--
-- Data for Name: vehicles; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO public.vehicles VALUES
	(4, 'Audi', 'A4', 2020, 75.00, 'Available', 1, NULL),
	(5, 'Honda', 'Civic', 2022, 60.00, 'Available', 1, NULL),
	(1, 'Toyota', 'Corolla', 2020, 50.00, 'Under Maintenance', 1, NULL),
	(2, 'Ford', 'Focus', 2019, 55.00, 'Available', 1, 4.50),
	(3, 'BMW', 'X5', 2021, 120.00, 'Available', 2, NULL);


--
-- Name: customers_customerid_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.customers_customerid_seq', 3, true);


--
-- Name: employee_employeeid_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.employee_employeeid_seq', 2, true);


--
-- Name: fines_fineid_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.fines_fineid_seq', 1, true);


--
-- Name: maintenancerecords_maintenanceid_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.maintenancerecords_maintenanceid_seq', 5, true);


--
-- Name: payments_paymentid_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.payments_paymentid_seq', 3, true);


--
-- Name: person_personid_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.person_personid_seq', 5, true);


--
-- Name: rentaltransactions_rentalid_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.rentaltransactions_rentalid_seq', 4, true);


--
-- Name: vehiclecategories_categoryid_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.vehiclecategories_categoryid_seq', 4, true);


--
-- Name: vehiclereviews_reviewid_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.vehiclereviews_reviewid_seq', 2, true);


--
-- Name: vehicles_vehicleid_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.vehicles_vehicleid_seq', 5, true);


--
-- Name: customers customers_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.customers
    ADD CONSTRAINT customers_pkey PRIMARY KEY (customerid);


--
-- Name: employee employee_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.employee
    ADD CONSTRAINT employee_pkey PRIMARY KEY (employeeid);


--
-- Name: fines fines_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.fines
    ADD CONSTRAINT fines_pkey PRIMARY KEY (fineid);


--
-- Name: maintenancerecords maintenancerecords_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.maintenancerecords
    ADD CONSTRAINT maintenancerecords_pkey PRIMARY KEY (maintenanceid);


--
-- Name: payments payments_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.payments
    ADD CONSTRAINT payments_pkey PRIMARY KEY (paymentid);


--
-- Name: person person_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.person
    ADD CONSTRAINT person_pkey PRIMARY KEY (personid);


--
-- Name: rentaltransactions rentaltransactions_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.rentaltransactions
    ADD CONSTRAINT rentaltransactions_pkey PRIMARY KEY (rentalid);


--
-- Name: vehiclecategories vehiclecategories_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.vehiclecategories
    ADD CONSTRAINT vehiclecategories_pkey PRIMARY KEY (categoryid);


--
-- Name: vehiclereviews vehiclereviews_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.vehiclereviews
    ADD CONSTRAINT vehiclereviews_pkey PRIMARY KEY (reviewid);


--
-- Name: vehicles vehicles_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.vehicles
    ADD CONSTRAINT vehicles_pkey PRIMARY KEY (vehicleid);


--
-- Name: rentaltransactions triggercalculateandinsertpaymentwithfine; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER triggercalculateandinsertpaymentwithfine AFTER UPDATE ON public.rentaltransactions FOR EACH ROW WHEN ((((new.status)::text = ANY ((ARRAY['Completed'::character varying, 'Late'::character varying])::text[])) AND ((old.status)::text <> ALL ((ARRAY['Completed'::character varying, 'Late'::character varying])::text[])))) EXECUTE FUNCTION public.calculateandinsertpaymentwithfine();


--
-- Name: maintenancerecords triggersetvehicleundermaintenance; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER triggersetvehicleundermaintenance AFTER INSERT OR UPDATE ON public.maintenancerecords FOR EACH ROW EXECUTE FUNCTION public.setvehicleundermaintenance();


--
-- Name: vehiclereviews triggerupdateaveragerating; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER triggerupdateaveragerating AFTER INSERT OR UPDATE ON public.vehiclereviews FOR EACH ROW EXECUTE FUNCTION public.updateaveragevehiclerating();


--
-- Name: rentaltransactions triggerupdatevehiclestatus; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER triggerupdatevehiclestatus AFTER INSERT OR UPDATE ON public.rentaltransactions FOR EACH ROW EXECUTE FUNCTION public.updatevehiclestatus();


--
-- Name: rentaltransactions triggervalidateandsetreturnstatus; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER triggervalidateandsetreturnstatus BEFORE INSERT OR UPDATE ON public.rentaltransactions FOR EACH ROW EXECUTE FUNCTION public.validateandsetreturnstatus();


--
-- Name: customers fk_customer_person; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.customers
    ADD CONSTRAINT fk_customer_person FOREIGN KEY (personid) REFERENCES public.person(personid) ON DELETE CASCADE;


--
-- Name: employee fk_employee_person; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.employee
    ADD CONSTRAINT fk_employee_person FOREIGN KEY (personid) REFERENCES public.person(personid) ON DELETE CASCADE;


--
-- Name: fines fk_fine_rental; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.fines
    ADD CONSTRAINT fk_fine_rental FOREIGN KEY (rentalid) REFERENCES public.rentaltransactions(rentalid) ON DELETE CASCADE;


--
-- Name: maintenancerecords fk_maintenance_vehicle; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.maintenancerecords
    ADD CONSTRAINT fk_maintenance_vehicle FOREIGN KEY (vehicleid) REFERENCES public.vehicles(vehicleid) ON DELETE CASCADE;


--
-- Name: payments fk_payment_rental; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.payments
    ADD CONSTRAINT fk_payment_rental FOREIGN KEY (rentalid) REFERENCES public.rentaltransactions(rentalid) ON DELETE CASCADE;


--
-- Name: rentaltransactions fk_rental_customer; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.rentaltransactions
    ADD CONSTRAINT fk_rental_customer FOREIGN KEY (customerid) REFERENCES public.customers(customerid) ON DELETE CASCADE;


--
-- Name: rentaltransactions fk_rental_vehicle; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.rentaltransactions
    ADD CONSTRAINT fk_rental_vehicle FOREIGN KEY (vehicleid) REFERENCES public.vehicles(vehicleid) ON DELETE CASCADE;


--
-- Name: vehiclereviews fk_review_customer; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.vehiclereviews
    ADD CONSTRAINT fk_review_customer FOREIGN KEY (customerid) REFERENCES public.customers(customerid) ON DELETE CASCADE;


--
-- Name: vehiclereviews fk_review_vehicle; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.vehiclereviews
    ADD CONSTRAINT fk_review_vehicle FOREIGN KEY (vehicleid) REFERENCES public.vehicles(vehicleid) ON DELETE CASCADE;


--
-- Name: vehicles fk_vehicle_category; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.vehicles
    ADD CONSTRAINT fk_vehicle_category FOREIGN KEY (categoryid) REFERENCES public.vehiclecategories(categoryid) ON DELETE CASCADE;


--
-- PostgreSQL database dump complete
--

