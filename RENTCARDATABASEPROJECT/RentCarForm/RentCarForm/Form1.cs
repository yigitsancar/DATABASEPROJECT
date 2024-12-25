using Npgsql;
using System.Data;

namespace RentCarForm
{
    public partial class Form1 : Form
    {
        public Form1()
        {
            InitializeComponent();
        }

        NpgsqlConnection connect = new NpgsqlConnection("server=localhost;port=5432;UserId=postgres;password=YygtT16;database=RentCar");


        private void button1_Click(object sender, EventArgs e)
        {
            try
            {
                connect.Open();
                string query = "SELECT * FROM RentalTransactions";
                NpgsqlDataAdapter da = new NpgsqlDataAdapter(query, connect);
                DataTable dt = new DataTable();
                da.Fill(dt);
                dataGridView1.DataSource = dt;
            }
            catch (Exception ex)
            {
                MessageBox.Show("Hata: " + ex.Message);
            }
            finally
            {
                connect.Close();
            }
        }


        private void button2_Click(object sender, EventArgs e)
        {
            try
            {
                int vehicleId = int.Parse(textBox1.Text);
                int customerId = int.Parse(textBox2.Text);
                DateTime startDate = dateTimePicker1.Value;
                DateTime endDate = dateTimePicker2.Value;

                string query = "INSERT INTO RentalTransactions (VehicleID, CustomerID, StartDate, EndDate) VALUES (@VehicleID, @CustomerID, @StartDate, @EndDate)";
                connect.Open();
                using (NpgsqlCommand cmd = new NpgsqlCommand(query, connect))
                {
                    cmd.Parameters.AddWithValue("@VehicleID", vehicleId);
                    cmd.Parameters.AddWithValue("@CustomerID", customerId);
                    cmd.Parameters.AddWithValue("@StartDate", startDate);
                    cmd.Parameters.AddWithValue("@EndDate", endDate);
                    cmd.ExecuteNonQuery();
                }
                MessageBox.Show("Kiralama işlemi başarıyla eklendi.");
            }
            catch (Exception ex)
            {
                MessageBox.Show("Hata: " + ex.Message);
            }
            finally
            {
                connect.Close();
            }
        }


        private void button3_Click(object sender, EventArgs e)
        {
            try
            {
                int rentalId = int.Parse(textBox3.Text); // Rental ID TextBox3'den alınıyor
                DateTime returnDate = DateTime.Now;

                string query = "UPDATE RentalTransactions SET ReturnDate = @ReturnDate, Status = 'Completed' WHERE RentalID = @RentalID AND Status = 'Active'";
                connect.Open();
                using (NpgsqlCommand cmd = new NpgsqlCommand(query, connect))
                {
                    cmd.Parameters.AddWithValue("@ReturnDate", returnDate);
                    cmd.Parameters.AddWithValue("@RentalID", rentalId);
                    int rowsAffected = cmd.ExecuteNonQuery();

                    if (rowsAffected > 0)
                        MessageBox.Show("İade işlemi başarıyla gerçekleştirildi.");
                    else
                        MessageBox.Show("İade işlemi başarısız oldu. Bu kiralama zaten tamamlanmış veya aktif değil.");
                }
            }
            catch (Exception ex)
            {
                MessageBox.Show("Hata: " + ex.Message);
            }
            finally
            {
                connect.Close();
            }
        }


        private void dataGridView1_CellContentClick(object sender, DataGridViewCellEventArgs e)
        {

        }

        private void textBox1_TextChanged(object sender, EventArgs e)
        {

        }

        private void textBox2_TextChanged(object sender, EventArgs e)
        {

        }

        private void textBox3_TextChanged(object sender, EventArgs e)
        {

        }

        private void dateTimePicker1_ValueChanged(object sender, EventArgs e)
        {

        }

        private void dateTimePicker2_ValueChanged(object sender, EventArgs e)
        {

        }
    }
}