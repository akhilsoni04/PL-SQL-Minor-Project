SET SERVEROUTPUT ON;

-- Bank Account Management System

/*
Domain: Banking
Features
Create customer and account
Deposit & withdraw money
Balance inquiry
Transaction history
Insufficient balance handling
PL/SQL Concepts Used
Stored procedures (deposit, withdraw)
Functions (get balance)
Triggers (auto-update balance, log transactions)
Exception handling
Sequences
Tables
customers
accounts
transactions

*/


-- Customers Table : Stores customer details

CREATE TABLE customers (
    customer_id NUMBER PRIMARY KEY,
    name        VARCHAR2(50),
    email       VARCHAR2(50),
    created_at  DATE DEFAULT SYSDATE
);

-- Accounts Table : Stores account info + balance

CREATE TABLE accounts (
    account_id  NUMBER PRIMARY KEY,
    customer_id NUMBER,
    balance     NUMBER(12,2),
    created_at  DATE DEFAULT SYSDATE,

    CONSTRAINT fk_customer
    FOREIGN KEY (customer_id)
    REFERENCES customers(customer_id)
);

-- Transactions Table : Stores deposit & withdraw logs

CREATE TABLE transactions (
    txn_id     NUMBER PRIMARY KEY,
    account_id NUMBER,
    txn_type   VARCHAR2(20),   -- DEPOSIT / WITHDRAW
    amount     NUMBER(12,2),
    txn_date   DATE DEFAULT SYSDATE,

    CONSTRAINT fk_account
    FOREIGN KEY (account_id)
    REFERENCES accounts(account_id)
);


CREATE SEQUENCE customer_seq START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE account_seq  START WITH 1001 INCREMENT BY 1;
CREATE SEQUENCE txn_seq      START WITH 1 INCREMENT BY 1;


-- Insert Customers
INSERT INTO customers VALUES (customer_seq.NEXTVAL,'Akhil','akhil@mail.com',SYSDATE);
INSERT INTO customers VALUES (customer_seq.NEXTVAL,'Rohit','rohit@mail.com',SYSDATE);
INSERT INTO customers VALUES (customer_seq.NEXTVAL,'Sneha','sneha@mail.com',SYSDATE);
INSERT INTO customers VALUES (customer_seq.NEXTVAL,'Priya','priya@mail.com',SYSDATE);
INSERT INTO customers VALUES (customer_seq.NEXTVAL,'Rahul','rahul@mail.com',SYSDATE);
INSERT INTO customers VALUES (customer_seq.NEXTVAL,'Aman','aman@mail.com',SYSDATE);
INSERT INTO customers VALUES (customer_seq.NEXTVAL,'Pooja','pooja@mail.com',SYSDATE);
INSERT INTO customers VALUES (customer_seq.NEXTVAL,'Kunal','kunal@mail.com',SYSDATE);
INSERT INTO customers VALUES (customer_seq.NEXTVAL,'Neha','neha@mail.com',SYSDATE);
INSERT INTO customers VALUES (customer_seq.NEXTVAL,'Ankit','ankit@mail.com',SYSDATE);

-- Accounts for each customer
INSERT INTO accounts VALUES (account_seq.NEXTVAL,1,5000,SYSDATE);
INSERT INTO accounts VALUES (account_seq.NEXTVAL,2,7000,SYSDATE);
INSERT INTO accounts VALUES (account_seq.NEXTVAL,3,12000,SYSDATE);
INSERT INTO accounts VALUES (account_seq.NEXTVAL,4,3000,SYSDATE);
INSERT INTO accounts VALUES (account_seq.NEXTVAL,5,9000,SYSDATE);
INSERT INTO accounts VALUES (account_seq.NEXTVAL,6,15000,SYSDATE);
INSERT INTO accounts VALUES (account_seq.NEXTVAL,7,8000,SYSDATE);
INSERT INTO accounts VALUES (account_seq.NEXTVAL,8,20000,SYSDATE);
INSERT INTO accounts VALUES (account_seq.NEXTVAL,9,6000,SYSDATE);
INSERT INTO accounts VALUES (account_seq.NEXTVAL,10,10000,SYSDATE);

COMMIT;



-- Returns current account balance

CREATE OR REPLACE FUNCTION get_balance (
    p_account_id NUMBER
) RETURN NUMBER AS
    v_balance NUMBER;
BEGIN
    SELECT balance INTO v_balance
    FROM accounts
    WHERE account_id = p_account_id;

    RETURN v_balance;
END;
/



-- Deposit amount + log transaction

CREATE OR REPLACE PROCEDURE deposit_money (
    p_account_id NUMBER,
    p_amount     NUMBER
) AS
BEGIN
    UPDATE accounts
    SET balance = balance + p_amount
    WHERE account_id = p_account_id;

    INSERT INTO transactions
    VALUES (txn_seq.NEXTVAL, p_account_id, 'DEPOSIT', p_amount, SYSDATE);

    COMMIT;
END;
/



-- Withdraw money + prevent overdraft using exception

CREATE OR REPLACE PROCEDURE withdraw_money (
    p_account_id NUMBER,
    p_amount     NUMBER
) AS
    v_balance NUMBER;
BEGIN
    SELECT balance INTO v_balance
    FROM accounts
    WHERE account_id = p_account_id;

    IF v_balance < p_amount THEN
        RAISE_APPLICATION_ERROR(-20001,'Insufficient Balance');
    END IF;

    UPDATE accounts
    SET balance = balance - p_amount
    WHERE account_id = p_account_id;

    INSERT INTO transactions
    VALUES (txn_seq.NEXTVAL, p_account_id, 'WITHDRAW', p_amount, SYSDATE);

    COMMIT;
END;
/



-- Trigger fires after account balance is updated

CREATE OR REPLACE TRIGGER trg_balance_update
AFTER UPDATE OF balance ON accounts
FOR EACH ROW
BEGIN
    DBMS_OUTPUT.PUT_LINE(
        'Balance updated for Account ' || :NEW.account_id
    );
END;
/


-- Deposit
BEGIN
   deposit_money(1001, 2000);
END;
/

-- Withdraw
BEGIN
   withdraw_money(1001, 1500);
END;
/

-- Check Balance
SELECT get_balance(1001) AS current_balance FROM dual;

-- View Transaction History
SELECT * FROM transactions WHERE account_id = 1001;


