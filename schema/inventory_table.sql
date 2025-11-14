-- Bookstore Inventory Table Schema
-- This table stores the inventory information for books across the distributed bookstore system

CREATE TABLE IF NOT EXISTS inventory (
    inventory_id SERIAL PRIMARY KEY,
    isbn VARCHAR(13) UNIQUE NOT NULL,
    book_title VARCHAR(255) NOT NULL,
    author VARCHAR(255) NOT NULL,
    publisher VARCHAR(255),
    publication_year INTEGER,
    quantity_available INTEGER NOT NULL DEFAULT 0,
    price DECIMAL(10, 2) NOT NULL,
    last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    node_id INTEGER NOT NULL,
    CONSTRAINT positive_quantity CHECK (quantity_available >= 0),
    CONSTRAINT positive_price CHECK (price >= 0)
);

-- Create indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_inventory_isbn ON inventory(isbn);
CREATE INDEX IF NOT EXISTS idx_inventory_book_title ON inventory(book_title);
CREATE INDEX IF NOT EXISTS idx_inventory_author ON inventory(author);
CREATE INDEX IF NOT EXISTS idx_inventory_node_id ON inventory(node_id);

-- Create a trigger to automatically update last_updated timestamp
CREATE OR REPLACE FUNCTION update_inventory_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.last_updated = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER inventory_update_timestamp
    BEFORE UPDATE ON inventory
    FOR EACH ROW
    EXECUTE FUNCTION update_inventory_timestamp();

-- Insert sample data for demonstration
INSERT INTO inventory (isbn, book_title, author, publisher, publication_year, quantity_available, price, node_id)
VALUES
    ('9780141439518', 'Pride and Prejudice', 'Jane Austen', 'Penguin Classics', 1813, 25, 12.99, 1),
    ('9780062315007', 'The Alchemist', 'Paulo Coelho', 'HarperOne', 1988, 30, 14.99, 1),
    ('9780451524935', '1984', 'George Orwell', 'Signet Classic', 1949, 40, 13.99, 1),
    ('9780061120084', 'To Kill a Mockingbird', 'Harper Lee', 'Harper Perennial', 1960, 20, 15.99, 1),
    ('9780743273565', 'The Great Gatsby', 'F. Scott Fitzgerald', 'Scribner', 1925, 35, 14.99, 1),
    ('9780316769488', 'The Catcher in the Rye', 'J.D. Salinger', 'Little, Brown', 1951, 28, 13.99, 1),
    ('9780547928227', 'The Hobbit', 'J.R.R. Tolkien', 'Mariner Books', 1937, 45, 16.99, 1),
    ('9780439708180', 'Harry Potter and the Sorcerer''s Stone', 'J.K. Rowling', 'Scholastic', 1997, 50, 12.99, 1),
    ('9780452284234', 'Animal Farm', 'George Orwell', 'Penguin Books', 1945, 32, 11.99, 1),
    ('9780141182605', 'Crime and Punishment', 'Fyodor Dostoevsky', 'Penguin Classics', 1866, 18, 16.99, 1);
