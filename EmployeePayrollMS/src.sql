/*
Employee Payroll Management System
Domain: HR / Corporate
Features
Employee details management
Salary calculation (basic + HRA + bonus − tax)
Monthly payslip generation
Department-wise salary report
PL/SQL Concepts Used
Packages (payroll_pkg)
Procedures (calculate_salary)
Functions (tax calculation)
Cursors (monthly report)
Triggers (audit salary changes)
Tables
employees
departments
salary_details
*/


-- Stores department information

CREATE TABLE departments (
    dept_id   NUMBER PRIMARY KEY,     -- unique dept id
    dept_name VARCHAR2(50)            -- department name
);


-- Stores employee details

CREATE TABLE employees (
    emp_id     NUMBER PRIMARY KEY,    -- employee id
    name       VARCHAR2(50),
    dept_id    NUMBER,                -- FK to departments
    basic_pay  NUMBER(10,2),          -- base salary
    hire_date  DATE DEFAULT SYSDATE,
    
    CONSTRAINT fk_dept
    FOREIGN KEY (dept_id)
    REFERENCES departments(dept_id)
);



-- Stores calculated salary components

CREATE TABLE salary_details (
    salary_id   NUMBER PRIMARY KEY,   -- salary record id
    emp_id      NUMBER,               -- employee reference
    basic_pay   NUMBER(10,2),
    hra         NUMBER(10,2),         -- House Rent Allowance
    bonus       NUMBER(10,2),
    tax_amount  NUMBER(10,2),
    net_salary  NUMBER(10,2),
    month_year  VARCHAR2(10),         -- e.g. JAN-2025
    created_at  DATE DEFAULT SYSDATE,

    CONSTRAINT fk_emp
    FOREIGN KEY (emp_id)
    REFERENCES employees(emp_id)
);


-- Stores calculated salary components

CREATE TABLE salary_details (
    salary_id   NUMBER PRIMARY KEY,   -- salary record id
    emp_id      NUMBER,               -- employee reference
    basic_pay   NUMBER(10,2),
    hra         NUMBER(10,2),         -- House Rent Allowance
    bonus       NUMBER(10,2),
    tax_amount  NUMBER(10,2),
    net_salary  NUMBER(10,2),
    month_year  VARCHAR2(10),         -- e.g. JAN-2025
    created_at  DATE DEFAULT SYSDATE,

    CONSTRAINT fk_emp
    FOREIGN KEY (emp_id)
    REFERENCES employees(emp_id)
);

-- 10 sample employees across departments

INSERT INTO employees VALUES (emp_seq.NEXTVAL,'Akhil',1,30000,SYSDATE);
INSERT INTO employees VALUES (emp_seq.NEXTVAL,'Rohit',2,45000,SYSDATE);
INSERT INTO employees VALUES (emp_seq.NEXTVAL,'Sneha',3,55000,SYSDATE);
INSERT INTO employees VALUES (emp_seq.NEXTVAL,'Priya',1,28000,SYSDATE);
INSERT INTO employees VALUES (emp_seq.NEXTVAL,'Ankit',4,40000,SYSDATE);
INSERT INTO employees VALUES (emp_seq.NEXTVAL,'Rahul',3,60000,SYSDATE);
INSERT INTO employees VALUES (emp_seq.NEXTVAL,'Neha',5,35000,SYSDATE);
INSERT INTO employees VALUES (emp_seq.NEXTVAL,'Kunal',2,48000,SYSDATE);
INSERT INTO employees VALUES (emp_seq.NEXTVAL,'Pooja',4,42000,SYSDATE);
INSERT INTO employees VALUES (emp_seq.NEXTVAL,'Aman',3,52000,SYSDATE);

COMMIT;


-- PACKAGE SPECIFICATION

CREATE OR REPLACE PACKAGE payroll_pkg AS
    PROCEDURE calculate_salary(p_emp_id NUMBER, p_month VARCHAR2);
    PROCEDURE dept_salary_report(p_dept_id NUMBER);
END payroll_pkg;
/


-- PACKAGE BODY IMPLEMENTATION
CREATE OR REPLACE PACKAGE BODY payroll_pkg AS


/*
  Calculates:
  HRA = 20% of basic
  Bonus = 10% of basic
  Tax = from calc_tax()
  Net Salary = basic + hra + bonus − tax
*/
PROCEDURE calculate_salary(p_emp_id NUMBER, p_month VARCHAR2) AS
    v_basic  NUMBER;
    v_hra    NUMBER;
    v_bonus  NUMBER;
    v_tax    NUMBER;
    v_net    NUMBER;
BEGIN
    SELECT basic_pay INTO v_basic
    FROM employees
    WHERE emp_id = p_emp_id;

    v_hra   := v_basic * 0.20;
    v_bonus := v_basic * 0.10;
    v_tax   := calc_tax(v_basic);
    v_net   := (v_basic + v_hra + v_bonus) - v_tax;

    INSERT INTO salary_details
    VALUES (
        sal_seq.NEXTVAL,
        p_emp_id, v_basic, v_hra, v_bonus,
        v_tax, v_net, p_month, SYSDATE
    );

    COMMIT;
END calculate_salary;


-- Prints salary report department-wise

PROCEDURE dept_salary_report(p_dept_id NUMBER) AS
    CURSOR c_emp IS
        SELECT e.emp_id, e.name, s.net_salary
        FROM employees e
        JOIN salary_details s ON e.emp_id = s.emp_id
        WHERE e.dept_id = p_dept_id;

BEGIN
    FOR rec IN c_emp LOOP
        DBMS_OUTPUT.PUT_LINE(
            'EMP: ' || rec.name || ' | Net Salary: ' || rec.net_salary
        );
    END LOOP;
END dept_salary_report;

END payroll_pkg;
/


-- Trigger logs salary modification

CREATE OR REPLACE TRIGGER trg_salary_audit
AFTER INSERT ON salary_details
FOR EACH ROW
BEGIN
    DBMS_OUTPUT.PUT_LINE(
        'Salary computed for EMP-ID ' || :NEW.emp_id
    );
END;
/


-- Calculate salary for an employee
BEGIN
   payroll_pkg.calculate_salary(101, 'JAN-2025');
END;
/

-- Department salary report
BEGIN
   payroll_pkg.dept_salary_report(3);
END;
/

-- View stored salary records
SELECT * FROM salary_details;
