--Library Management System Project

--Project task

--Q1. Create a New Book Record -- "978-1-60129-456-2', 'To Kill a Mockingbird', 'Classic', 6.00, 'yes', 'Harper Lee', 
-- 'J.B. Lippincott & Co.')" 

INSERT INTO books 
values 
(
	'978-1-60129-456-2', 'to Kill a Mockingbird', 'Classic', 6.00, 'yes', 'Harper Lee', 
'J.B. Lippincott & Co.')

--Q2. Update an Existing Member's Address
UPDATE members
SET member_address = '125 Oak St'
WHERE member_id = 'C103';

--Q3.  Delete the record with issued_id = 'IS121' from the issued_status table.
DELETE FROM issued_status
WHERE issued_id = 'IS121'

--Q4. Select all books issued by the employee with emp_id = 'E101'.
SELECT 
	issued_id,
	issued_member_id,
	issued_book_name,
	issued_date,
	issued_book_isbn,
	iss.issued_emp_id,
	book_title
FROM books b
LEFT JOIN issued_status iss ON b.isbn = iss.issued_book_isbn
LEFT JOIN employees e ON e.emp_id = iss.issued_emp_id
WHERE emp_id = 'E101'

SELECT * FROM issued_status
WHERE issued_emp_id = 'E101'

--Q5 Use GROUP BY to find members who have issued more than one book
SELECT 
	issued_member_id,
	COUNT(*)
FROM issued_status
GROUP BY 1
ORDER BY 2 DESC
LIMIT 6;

-- Q6 Used CTAS to generate new tables based on query results 
-- each book and total book_issued_cnt
CREATE TABLE books_issued_cnt AS 
(
	SELECT 
		iss.issued_book_isbn,
		b.book_title,
		COUNT(iss.issued_id) AS total_books_issued
	FROM issued_status iss
	LEFT JOIN books b ON b.isbn = iss.issued_book_isbn
	GROUP BY 1, 2
) 

-- Q7.  Retrieve All Books in a Classic Category
SELECT 
*
FROM books
WHERE category = 'Classic'

-- Q8. Find Total Rental Income by Category
SELECT 
	category,
	SUM(rental_price) total_rental_income
FROM books
GROUP BY 1

-- Q9 List Members Who Registered in the Last 180 Days
SELECT * FROM members
WHERE reg_date >= CURRENT_DATE - INTERVAL '180 DAYS'


--Q10. List Employees with Their Branch Manager's Name and their branch details

SELECT 
	e.emp_id,
	e.emp_name,
	b.*,
	e1.emp_name AS manager
FROM employees e
LEFT JOIN branch b ON e.branch_id = b.branch_id
LEFT JOIN employees e1 ON e1.emp_id = b.manager_id

--Q11 Create a Table of Books with Rental Price Above a Certain Threshold
CREATE TABLE expensive_books AS
SELECT * FROM books
WHERE rental_price > 7.00;

--Q12  Retrieve the List of Books Not Yet Returned
SELECT 
	iss.issued_id,
	iss.issued_book_name,
	iss.issued_date,
	iss.issued_book_isbn,
	rs.return_id,
	rs.return_date
FROM issued_status iss
LEFT JOIN return_status rs ON iss.issued_id = rs.issued_id
WHERE return_book_isbn IS NULL

-- Q13 Write a query to identify members who have overdue books 
--(assume a 30-day return period). Display the member's_id, member's name,
--book title, issue date, and days overdue.
SELECT 
	 m.member_id,
	 m.member_name,
	 b.book_title,
	 iss.issued_date,
	 CURRENT_DATE - iss.issued_date AS days_overdue
FROM issued_status iss
LEFT JOIN return_status rs ON iss.issued_id = rs.issued_id
LEFT JOIN members m ON m.member_id = iss.issued_member_id
LEFT JOIN books b ON b.isbn = iss.issued_book_isbn
WHERE rs.return_date IS NULL
	AND
 (CURRENT_DATE - iss.issued_date) > 30
ORDER BY 1
 
-- Q14. Write a query to update the status of books in the books table to 
-- "Yes" when they are returned (based on entries in the return_status table)

-- stored procedure
CREATE OR REPLACE PROCEDURE 
		add_return_records(p_return_id VARCHAR(10), p_issued_id VARCHAR(10), p_book_quality VARCHAR(50))
LANGUAGE plpgsql
AS $$

	DECLARE 
	v_isbn VARCHAR(50);
	v_book_name VARCHAR(80);
BEGIN
	-- inserting into records based on users input
	INSERT INTO return_status (return_id, issued_id, return_date, book_quality)
	VALUES
		(p_return_id, p_issued_id, CURRENT_DATE, p_book_quality);

	SELECT 
		issued_book_isbn,
		issued_book_name
		INTO 
		v_isbn,
		v_book_name
	FROM issued_status
	WHERE issued_id = p_issued_id;
	
	UPDATE books
	SET status = 'yes'
	WHERE isbn = v_isbn;

	RAISE NOTICE 'Thank you for returning the book: %', v_book_name;
END;
$$

CALL add_return_records('RS142', 'IS119', 'Good');

--Q15 Create a query that generates a performance report for each branch, showing 
	--the number of books issued, the number of books returned, and the total 
	--revenue generated from book rentals.
CREATE TABLE branch_report AS 
	SELECT 
		b.branch_id,
		b.manager_id,
		COUNT(iss.issued_id) AS issued_book,
		COUNT(rs.return_id) AS returned_books,
		SUM(bs.rental_price) AS total_revenue,
		RANK() OVER (ORDER BY SUM(bs.rental_price)DESC) AS rank_performance
	FROM books bs
	LEFT JOIN issued_status iss ON bs.isbn = iss.issued_book_isbn
	LEFT JOIN employees es ON es.emp_id = iss.issued_emp_id
	LEFT JOIN branch b ON b.branch_id = es.branch_id
	LEFT JOIN return_status rs ON rs.issued_id = iss.issued_id
	WHERE b.branch_id IS NOT NULL
	GROUP BY 1;

SELECT * FROM branch_report;

/*Q16 Use the CREATE TABLE AS (CTAS) statement to create a new table active_members 
containing members who have issued at least one book in the last 18 months.*/
CREATE TABLE active_members AS
	SELECT 
		m.member_id,
		m.member_name,
		iss.issued_id,
		iss.issued_date
	FROM members m
	LEFT JOIN issued_status iss ON m.member_id = iss.issued_member_id
	WHERE issued_date >= CURRENT_DATE - INTERVAL '2 MONTHS'

-- sub query
SELECT * FROM members 
WHERE member_id IN (
	SELECT 
		DISTINCT m.member_id
	FROM members m
	LEFT JOIN issued_status iss ON m.member_id = iss.issued_member_id
	WHERE issued_date >= CURRENT_DATE - INTERVAL '2 MONTHS'
)
	
--Q17 Write a query to find the top 3 employees who have processed the most book 
	--issues. Display the employee name, number of books processed, and their branch
SELECT 
	DISTINCT es.emp_id,
	es.emp_name,
	COUNT(iss.issued_book_isbn) AS issued_books,
	bh.branch_id
	--RANK () OVER (ORDER BY COUNT(iss.issued_book_isbn)DESC) AS ranking
FROM issued_status iss
LEFT JOIN employees es ON iss.issued_emp_id = es.emp_id
LEFT JOIN branch bh ON bh.branch_id = es.branch_id
GROUP BY 1, 4
ORDER BY 3 DESC
LIMIT 3
	
--Q18 Write a query to identify members who have issued books more than twice with 
	--the status "damaged" in the books table. Display the member name, book title, 
	--and the number of times they've issued damaged books
SELECT 
	m.member_name,
	b.book_title,
	COUNT(iss.issued_id) AS number_damaged
FROM issued_status iss
LEFt JOIN books b ON iss.issued_book_isbn = b.isbn
LEFT JOIN members m ON m.member_id = iss.issued_member_id
WHERE b.book_quality = 'damaged'
GROUP BY 1, 2



/*Q19 Write a stored procedure that updates the status of a book in the library based on its issuance.

The procedure should function as follows: 
--The stored procedure should take the book_id as an input parameter. 

--The procedure should first check if the book is available (status = 'yes'). 

--If the book is available, It should be issued, and the status in the books table should be updated to 
'no'.

--If the book is not available (status = 'no'), the procedure should return an error message indicating 
that the book is currently not available.*/

-- testing queries
SELECT * FROM books
WHERE status = 'yes';

SELECT * FROM issued_status;

--creating the procedure
CREATE OR REPLACE PROCEDURE issued_book ( 
		p_issued_id VARCHAR(10), p_issued_member_id VARCHAR(30),p_issued_book_name VARCHAR(80),
				p_issued_book_isbn VARCHAR(50), p_issued_emp_id VARCHAR(10))
		
	LANGUAGE plpgsql
AS $$

	DECLARE 
--declare variables
	v_status VARCHAR(10);
	
	BEGIN
--begin code logic
	--checking if book is available '= yes'
	SELECT 
		status
		INTO
		v_status
	FROM books
		WHERE isbn = p_issued_book_isbn;

	IF v_status = 'yes' THEN 
		INSERT INTO issued_status
				(issued_id, issued_member_id, issued_book_name, issued_date,
						issued_book_isbn, issued_emp_id)
		VALUES
				(p_issued_id, p_issued_member_id, p_issued_book_name, CURRENT_DATE, 
					p_issued_book_isbn, p_issued_emp_id );

					UPDATE books
					SET status = 'no'
					WHERE isbn = p_issued_book_isbn;
					
		RAISE NOTICE 'Book records added successfully book_isbn: %', p_issued_book_isbn;
		
	ELSE
		RAISE NOTICE 'Sorry! the book is not available book_isbn: %', p_issued_book_isbn;
		
	END IF;

END;
$$

CALL issued_book ('IS142', 'C110', 'The Diary of a Young Girl', '978-0-375-41398-8', 'E109')

SELECT * FROM books
WHERE status = 'yes'

SELECT * FROM books
"978-0-553-29698-2" -- yes
"978-0-375-41398-8" -- no

SELECT * FROM books 
WHERE isbn = '978-0-375-41398-8'

--Q20 Create a CTAS (Create Table As Select) query to identify overdue books .
CREATE TABLE books_overdue AS 
	SELECT 
		 DISTINCT b.isbn,
		 b.book_title,
		 b.category,
		 iss.issued_date,
		 CURRENT_DATE - iss.issued_date AS days_overdue
	FROM issued_status iss
	LEFT JOIN return_status rs ON iss.issued_id = rs.issued_id
	LEFT JOIN members m ON m.member_id = iss.issued_member_id
	LEFT JOIN books b ON b.isbn = iss.issued_book_isbn
	WHERE rs.return_date IS NULL
		AND
	 (CURRENT_DATE - iss.issued_date) > 30
	ORDER BY 1 DESC






