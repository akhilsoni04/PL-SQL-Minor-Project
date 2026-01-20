NOTE : This file contain line by line complete work of my single window.
THEN i am oraganize those code seprately based on folder structure.







-- Employee Management System 
SET SERVEROUTPUT ON;

-- System Component First (1)
-- Step 1 Creation of major table 
CREATE TABLE departments (
    department_id NUMBER PRIMARY KEY,
    department_name VARCHAR2(100) NOT NULL UNIQUE
);

-- step 2 employees table 
CREATE TABLE employees(
    employee_id NUMBER PRIMARY KEY,
    first_name VARCHAR2(50) NOT NULL,
    last_name VARCHAR2(50) NOT NULL,
    email VARCHAR2(100) UNIQUE,
    salary NUMBER(10,2) CHECK(salary > 0),
    department_id NUMBER NOT NULL,
    hire_date DATE DEFAULT SYSDATE,
    FOREIGN KEY (department_id) REFERENCES departments(department_id)
);

-- Step 3 Table for salary history
CREATE TABLE salary_history(
    history_id NUMBER PRIMARY KEY,
    employee_id NUMBER NOT NULL,
    old_salary NUMBER(10,2),
    new_salary NUMBER(10,2),
    change_date DATE DEFAULT SYSDATE,
    FOREIGN KEY (employee_id) REFERENCES employees(employee_id)
);


-- System Component Second (2)
-- Package Specification {Procedures , Function}
CREATE OR REPLACE PACKAGE emp_management 
IS 
    -- Procedure Will do actions (insert/update/delete)
    PROCEDURE hire_employee (
        p_emp_id IN NUMBER,
        p_first_name IN VARCHAR2,
        p_last_name IN VARCHAR2,
        p_email IN VARCHAR2,
        p_salary IN NUMBER,
        p_dept_id IN NUMBER
    );
    
    PROCEDURE update_salary(
        p_emp_id IN NUMBER,
        p_new_salary IN NUMBER
    );
    
    -- Return something (bonus amount)
    FUNCTION calculate_bonus(
        p_emp_id IN NUMBER,
        p_bonus_percent IN NUMBER
    ) 
    RETURN NUMBER;
    
    PROCEDURE terminate_employee(
        p_emp_id IN NUMBER
    );

END emp_management;
/

-- Package BODY 

CREATE OR REPLACE PACKAGE BODY emp_management
IS
  PROCEDURE hire_employee (
    p_emp_id      IN NUMBER,
    p_first_name  IN VARCHAR2,
    p_last_name   IN VARCHAR2,
    p_email       IN VARCHAR2,
    p_salary      IN NUMBER,
    p_dept_id     IN NUMBER
  )
  IS
    v_count NUMBER;
  BEGIN
    IF p_salary <= 0 THEN
      RAISE_APPLICATION_ERROR(-20001, 'Salary must be greater than 0');
    END IF;

    SELECT COUNT(*)
    INTO v_count
    FROM departments
    WHERE department_id = p_dept_id;

    IF v_count = 0 THEN
      RAISE_APPLICATION_ERROR(-20002, 'Department does not exist');
    END IF;

    INSERT INTO employees(employee_id, first_name, last_name, email, salary, department_id)
    VALUES (p_emp_id, p_first_name, p_last_name, p_email, p_salary, p_dept_id);

    COMMIT;
  EXCEPTION
    WHEN DUP_VAL_ON_INDEX THEN
      ROLLBACK;
      RAISE_APPLICATION_ERROR(-20003, 'Duplicate employee id/email');
    WHEN OTHERS THEN
      ROLLBACK;
      RAISE_APPLICATION_ERROR(-20099, 'Hire employee failed: ' || SQLERRM);
  END hire_employee;


  PROCEDURE update_salary(
    p_emp_id      IN NUMBER,
    p_new_salary  IN NUMBER
  )
  IS
  BEGIN
    IF p_new_salary <= 0 THEN
      RAISE_APPLICATION_ERROR(-20011, 'New salary must be greater than 0');
    END IF;

    UPDATE employees
    SET salary = p_new_salary
    WHERE employee_id = p_emp_id;

    IF SQL%ROWCOUNT = 0 THEN
      RAISE_APPLICATION_ERROR(-20012, 'Employee not found');
    END IF;

    COMMIT; -- trigger will insert into salary_history
  EXCEPTION
    WHEN OTHERS THEN
      ROLLBACK;
      RAISE_APPLICATION_ERROR(-20098, 'Update salary failed: ' || SQLERRM);
  END update_salary;


  FUNCTION calculate_bonus(
    p_emp_id        IN NUMBER,
    p_bonus_percent IN NUMBER
  ) RETURN NUMBER
  IS
    v_salary employees.salary%TYPE;
  BEGIN
    IF p_bonus_percent < 0 OR p_bonus_percent > 1 THEN
      RAISE_APPLICATION_ERROR(-20021, 'Bonus percent must be between 0 and 1');
    END IF;

    SELECT salary INTO v_salary
    FROM employees
    WHERE employee_id = p_emp_id;

    RETURN v_salary * p_bonus_percent;

  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      RAISE_APPLICATION_ERROR(-20022, 'Employee not found for bonus calculation');
  END calculate_bonus;


  PROCEDURE terminate_employee(
    p_emp_id IN NUMBER
  )
  IS
  BEGIN
    UPDATE employees
    SET status = 'TERMINATED'
    WHERE employee_id = p_emp_id;

    IF SQL%ROWCOUNT = 0 THEN
      RAISE_APPLICATION_ERROR(-20031, 'Employee not found');
    END IF;

    COMMIT;
  EXCEPTION
    WHEN OTHERS THEN
      ROLLBACK;
      RAISE_APPLICATION_ERROR(-20097, 'Termination failed: ' || SQLERRM);
  END terminate_employee;

END emp_management;
/






-- System COMPONENT 3 
-- Trigger's

-- SEQUENCE ON trigger
CREATE SEQUENCE salary_history_seq
START WITH 1
INCREMENT BY 1;



-- Salary Audit Trigger
CREATE OR REPLACE TRIGGER emp_salary_audit
AFTER UPDATE OF salary ON employees
FOR EACH ROW 

BEGIN 
    INSERT INTO salary_history (history_id, employee_id, old_salary, new_salary, change_date) 
    VALUES (salary_history_seq.NEXTVAL, :OLD.employee_id, :OLD.salary, :NEW.salary, SYSDATE);    
END emp_salary_audit;
/

/*
AFTER UPDATE OF salary means trigger runs only when salary changes
:OLD = previous row values
:NEW = updated row values
Audit/history table ensures tracking (very important in HR/Payroll)
*/


-- Hire Date Validation Trigger
CREATE OR REPLACE TRIGGER emp_hire_date_check
BEFORE INSERT ON employees
FOR EACH ROW
BEGIN
  IF :NEW.hire_date IS NOT NULL AND :NEW.hire_date > SYSDATE THEN
    RAISE_APPLICATION_ERROR(-20001, 'Hire date cannot be in future');
  END IF;
END emp_hire_date_check;
/



-- Component 4: Complex Queries
-- Employees earning above department average
SELECT 
  e.first_name || ' ' || e.last_name AS emp_name,
  e.salary,
  (SELECT ROUND(AVG(salary), 2)
     FROM employees
    WHERE department_id = e.department_id) AS dept_avg
FROM employees e
WHERE e.salary >
  (SELECT AVG(salary)
     FROM employees
    WHERE department_id = e.department_id);

--This is a correlated subquery because it depends on e.department_id from outer query.


-- Rank employees by salary within department
SELECT 
  e.first_name || ' ' || e.last_name AS emp_name,
  e.salary, e.department_id,
  RANK() OVER (PARTITION BY e.department_id ORDER BY e.salary DESC) 
  AS
  rank_in_dept FROM employees e;


-- Find top 3 highest paid employees in each department / By this below line you can do it 
SELECT *
FROM (
  SELECT 
    e.first_name || ' ' || e.last_name AS emp_name,
    e.department_id,
    e.salary,
    DENSE_RANK() OVER (PARTITION BY e.department_id ORDER BY e.salary DESC) AS rnk
  FROM employees e
)
WHERE rnk <= 3;


-- Component 5: Performance Optimization (Indexes)
-- Create index on frequently searched columns

CREATE INDEX idx_emp_dept ON employees(department_id);
CREATE INDEX idx_emp_salary ON employees(salary);
CREATE INDEX idx_emp_name ON employees(UPPER(last_name));

-- Index = improves SELECT performance (search/filter/sort) by avoiding full table scan.


-- idx_emp_dept → speeds queries like:
SELECT * FROM employees WHERE department_id = 10;

-- idx_emp_salary → speeds queries like:
SELECT * FROM employees WHERE salary > 50000;

-- idx_emp_name ON UPPER(last_name) → this is a function-based index
-- Helps queries like:
SELECT * FROM employees WHERE UPPER(last_name) = 'SONI';



-- LAsat component

-- Setup department first
BEGIN
  INSERT INTO departments(department_id, department_name)
  VALUES (10, 'IT');
  COMMIT;
EXCEPTION
  WHEN DUP_VAL_ON_INDEX THEN
    NULL; -- already exists
END;
/

-- Test hire employee
BEGIN
  emp_management.hire_employee(
    p_emp_id      => 101,
    p_first_name  => 'John',
    p_last_name   => 'Doe',
    p_email       => 'john@example.com',
    p_salary      => 50000,
    p_dept_id     => 10
  );
  DBMS_OUTPUT.PUT_LINE('Employee hired successfully');
END;
/

-- Test calculate bonus
DECLARE
  v_bonus NUMBER;
BEGIN
  v_bonus := emp_management.calculate_bonus(101, 0.15);
  DBMS_OUTPUT.PUT_LINE('Bonus: ' || v_bonus);
END;
/

-- Test update salary
BEGIN
  emp_management.update_salary(101, 55000);
  DBMS_OUTPUT.PUT_LINE('Salary updated');
END;
/

-- Test salary history
SELECT * FROM salary_history WHERE employee_id = 101;




-- ERROR Testing 
SHOW ERRORS PACKAGE BODY emp_management;

ALTER TABLE employees
ADD status VARCHAR2(15) DEFAULT 'ACTIVE'
CHECK (status IN ('ACTIVE','TERMINATED'));


SELECT object_name, object_type, status
FROM user_objects
WHERE object_name = 'EMP_MANAGEMENT';
