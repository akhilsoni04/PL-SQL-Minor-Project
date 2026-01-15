/*=========================================================
   LIBRARY MANAGEMENT SYSTEM (PL/SQL MINI PROJECT)
   Domain      : Education / Institution
   Features    :
     - Book issue & return
     - Fine calculation
     - Member management
     - Availability check
     - Overdue report

   PL/SQL Concepts Used:
     - Function    : Fine calculation
     - Procedures  : Issue / Return book
     - Cursor      : Overdue report list
     - Package     : Organize procedures
     - Trigger     : Auto fine calculation

=========================================================*/


/*=========================================================
  1) TABLES
=========================================================*/

-- Table 1: Stores book details & availability status
CREATE TABLE books (
    book_id      NUMBER PRIMARY KEY,
    title        VARCHAR2(100),
    author       VARCHAR2(50),
    total_copies NUMBER,
    available    NUMBER,                       -- currently available copies
    created_at   DATE DEFAULT SYSDATE
);

-- Table 2: Stores library member details
CREATE TABLE members (
    member_id  NUMBER PRIMARY KEY,
    name       VARCHAR2(50),
    email      VARCHAR2(50),
    join_date  DATE DEFAULT SYSDATE
);

-- Table 3: Stores issue & return transaction records
CREATE TABLE issue_return (
    tran_id     NUMBER PRIMARY KEY,
    book_id     NUMBER,
    member_id   NUMBER,
    issue_date  DATE,
    due_date    DATE,                          -- Issue date + 14
    return_date DATE,                          -- NULL until returned
    fine        NUMBER(8,2),                   -- fine amount

    -- Foreign key to book table
    CONSTRAINT fk_book
        FOREIGN KEY (book_id) REFERENCES books(book_id),

    -- Foreign key to members table
    CONSTRAINT fk_member
        FOREIGN KEY (member_id) REFERENCES members(member_id)
);


/*=========================================================
  2) SEQUENCES
     Used to auto-generate unique IDs
=========================================================*/
CREATE SEQUENCE book_seq   START WITH 1    INCREMENT BY 1;
CREATE SEQUENCE member_seq START WITH 101  INCREMENT BY 1;
CREATE SEQUENCE tran_seq   START WITH 1001 INCREMENT BY 1;


/*=========================================================
  3) INSERT SAMPLE DATA
=========================================================*/

-- Insert Books
INSERT INTO books VALUES (book_seq.NEXTVAL,'DBMS Concepts','Korth',5,5,SYSDATE);
INSERT INTO books VALUES (book_seq.NEXTVAL,'Operating Systems','Galvin',4,4,SYSDATE);
INSERT INTO books VALUES (book_seq.NEXTVAL,'Java Programming','Herbert',6,6,SYSDATE);
INSERT INTO books VALUES (book_seq.NEXTVAL,'SQL Guide','Bob',3,3,SYSDATE);
INSERT INTO books VALUES (book_seq.NEXTVAL,'Python Basics','Mark',7,7,SYSDATE);
INSERT INTO books VALUES (book_seq.NEXTVAL,'Machine Learning','Tom',5,5,SYSDATE);
INSERT INTO books VALUES (book_seq.NEXTVAL,'Data Structures','Lafore',4,4,SYSDATE);
INSERT INTO books VALUES (book_seq.NEXTVAL,'Computer Networks','Tanenbaum',6,6,SYSDATE);
INSERT INTO books VALUES (book_seq.NEXTVAL,'Cloud Computing','Raj',3,3,SYSDATE);
INSERT INTO books VALUES (book_seq.NEXTVAL,'Cyber Security','James',5,5,SYSDATE);
COMMIT;

-- Insert Members
INSERT INTO members VALUES (member_seq.NEXTVAL,'Akhil','akhil@mail.com',SYSDATE);
INSERT INTO members VALUES (member_seq.NEXTVAL,'Rohit','rohit@mail.com',SYSDATE);
INSERT INTO members VALUES (member_seq.NEXTVAL,'Sneha','sneha@mail.com',SYSDATE);
INSERT INTO members VALUES (member_seq.NEXTVAL,'Priya','priya@mail.com',SYSDATE);
INSERT INTO members VALUES (member_seq.NEXTVAL,'Rahul','rahul@mail.com',SYSDATE);
INSERT INTO members VALUES (member_seq.NEXTVAL,'Pooja','pooja@mail.com',SYSDATE);
INSERT INTO members VALUES (member_seq.NEXTVAL,'Aman','aman@mail.com',SYSDATE);
INSERT INTO members VALUES (member_seq.NEXTVAL,'Kunal','kunal@mail.com',SYSDATE);
INSERT INTO members VALUES (member_seq.NEXTVAL,'Neha','neha@mail.com',SYSDATE);
INSERT INTO members VALUES (member_seq.NEXTVAL,'Ankit','ankit@mail.com',SYSDATE);
COMMIT;


/*=========================================================
  4) FUNCTION: Fine Calculation
     Fine Rule: ₹5/day after due date
=========================================================*/
CREATE OR REPLACE FUNCTION calc_fine(p_due DATE, p_return DATE)
RETURN NUMBER AS
    v_days NUMBER;
BEGIN
    -- date subtraction gives number of days
    v_days := p_return - p_due;

    IF v_days > 0 THEN
        RETURN v_days * 5;     -- ₹5 per day late
    ELSE
        RETURN 0;              -- no fine if returned early/on-time
    END IF;
END;
/


/*=========================================================
  5) PACKAGE: library_pkg
     Contains all library procedures
=========================================================*/

-- Package specification (declaration)
CREATE OR REPLACE PACKAGE library_pkg AS
    PROCEDURE issue_book(p_book_id NUMBER, p_member_id NUMBER);
    PROCEDURE return_book(p_tran_id NUMBER, p_return DATE);
    PROCEDURE overdue_report;
END library_pkg;
/

-- Package body (implementation)
CREATE OR REPLACE PACKAGE BODY library_pkg AS


    /*-----------------------------------------------------
      PROCEDURE: issue_book
      - check availability
      - reduce available copies
      - create issue transaction with due date + 14 days
    -----------------------------------------------------*/
    PROCEDURE issue_book(p_book_id NUMBER, p_member_id NUMBER) AS
        v_available NUMBER;
    BEGIN
        -- Step 1: check current availability of that book
        SELECT available INTO v_available
        FROM books
        WHERE book_id = p_book_id;

        -- Step 2: if not available, stop
        IF v_available = 0 THEN
            RAISE_APPLICATION_ERROR(-20001,'Book Not Available');
        END IF;

        -- Step 3: reduce available copies by 1
        UPDATE books
        SET available = available - 1
        WHERE book_id = p_book_id;

        -- Step 4: create issue record, due in 14 days
        INSERT INTO issue_return
        VALUES (
            tran_seq.NEXTVAL,
            p_book_id,
            p_member_id,
            SYSDATE,
            SYSDATE + 14,
            NULL,       -- return_date NULL until return
            0
        );

        COMMIT;
    END issue_book;


    /*-----------------------------------------------------
      PROCEDURE: return_book
      - updates return date
      - calculates fine
      - increases available copies
    -----------------------------------------------------*/
    PROCEDURE return_book(p_tran_id NUMBER, p_return DATE) AS
        v_due  DATE;
        v_book NUMBER;
        v_fine NUMBER;
    BEGIN
        -- Step 1: fetch due_date + book_id for transaction
        SELECT due_date, book_id
        INTO v_due, v_book
        FROM issue_return
        WHERE tran_id = p_tran_id;

        -- Step 2: calculate fine using function
        v_fine := calc_fine(v_due, p_return);

        -- Step 3: update transaction with return date + fine
        UPDATE issue_return
        SET return_date = p_return,
            fine = v_fine
        WHERE tran_id = p_tran_id;

        -- Step 4: increase book availability by 1
        UPDATE books
        SET available = available + 1
        WHERE book_id = v_book;

        COMMIT;
    END return_book;


    /*-----------------------------------------------------
      PROCEDURE: overdue_report
      - shows members who did not return books after due date
      - uses cursor to fetch each overdue row one by one
    -----------------------------------------------------*/
    PROCEDURE overdue_report AS
        CURSOR c_overdue IS
            SELECT m.name, b.title, i.due_date
            FROM issue_return i
            JOIN members m ON i.member_id = m.member_id
            JOIN books b ON i.book_id = b.book_id
            WHERE i.return_date IS NULL
              AND i.due_date < SYSDATE;
    BEGIN
        FOR rec IN c_overdue LOOP
            DBMS_OUTPUT.PUT_LINE(
                'Member: ' || rec.name ||
                ' | Book: ' || rec.title ||
                ' | Due Date: ' || rec.due_date
            );
        END LOOP;
    END overdue_report;

END library_pkg;
/


/*=========================================================
  6) TRIGGER: trg_auto_fine
     Auto fine update whenever return_date is updated
=========================================================*/
CREATE OR REPLACE TRIGGER trg_auto_fine
BEFORE UPDATE OF return_date ON issue_return
FOR EACH ROW
BEGIN
    -- Automatically recompute fine when return_date changes
    :NEW.fine := calc_fine(:OLD.due_date, :NEW.return_date);
END;
/


/*=========================================================
  7) TESTING THE SYSTEM
=========================================================*/

-- 1) Issue a book (book_id=1 to member_id=101)
BEGIN
   library_pkg.issue_book(1,101);
END;
/

-- 2) Return it late (5 days late)
BEGIN
   library_pkg.return_book(1001, SYSDATE + 5);
END;
/

-- 3) View issue/return history
SELECT * FROM issue_return;

-- 4) Run overdue report
BEGIN
   library_pkg.overdue_report;
END;
/
