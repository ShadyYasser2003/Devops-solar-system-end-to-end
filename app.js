const path = require('path');
const express = require('express');
const OS = require('os');
const bodyParser = require('body-parser');
const mongoose = require("mongoose");
const cors = require('cors');

const app = express();

app.use(bodyParser.json());
app.use(express.static(path.join(__dirname, '/')));
app.use(cors());

// MongoDB connection
const mongoUri = process.env.MONGO_URI;

mongoose.connect(mongoUri, {
  useNewUrlParser: true,
  useUnifiedTopology: true,
})
  .then(() => {
    console.log("✅ Connected to MongoDB Atlas");
  })
  .catch((err) => {
    console.error("❌ MongoDB connection error:", err);
    process.exit(1);
  });

const Schema = mongoose.Schema;

const dataSchema = new Schema({
  name: String,
  id: Number,
  description: String,
  image: String,
  velocity: String,
  distance: String
});

const planetModel = mongoose.model('planets', dataSchema);

// ✅ تعديل هنا: async/await بدل callback
app.post('/planet', async (req, res) => {
  try {
    const planetData = await planetModel.findOne({ id: req.body.id });

    if (!planetData) {
      return res.status(404).send("❌ Planet not found. Please select a number from 0 - 9.");
    }

    res.json(planetData);
  } catch (err) {
    console.error("❌ Error fetching planet:", err);
    res.status(500).send("Error in Planet Data");
  }
});

app.get('/', async (req, res) => {
  res.sendFile(path.join(__dirname, '/', 'index.html'));
});

app.get('/os', (req, res) => {
  res.setHeader('Content-Type', 'application/json');
  res.send({
    "os": OS.hostname(),
    "env": process.env.NODE_ENV
  });
});

app.get('/live', (req, res) => {
  res.setHeader('Content-Type', 'application/json');
  res.send({
    "status": "live"
  });
});

app.get('/ready', (req, res) => {
  res.setHeader('Content-Type', 'application/json');
  res.send({
    "status": "ready"
  });
});

app.listen(3000, () => {
  console.log("Server successfully running on port - " + 3000);
});

module.exports = app;
