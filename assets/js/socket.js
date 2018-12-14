// NOTE: The contents of this file will only be executed if
// you uncomment its entry in "assets/js/app.js".

// To use Phoenix channels, the first step is to import Socket,
// and connect at the socket path in "lib/web/endpoint.ex".
//
// Pass the token on params as below. Or remove it
// from the params if you are not using authentication.
import {Socket} from "phoenix"

let socket = new Socket("/socket", {params: {token: window.userToken}})


socket.connect()

// Now that you are connected, you can join channels with a topic:
let channel = socket.channel("room:lobby", {})

channel.join()
  .receive("ok", resp => { console.log("Joined successfully", resp) })
  .receive("error", resp => { console.log("Unable to join", resp) })

export default socket

let messagesContainer = $("#messages");
let messagesContainer2 = $("#reward");

// Charts
var ctx = document.getElementById('myChart').getContext('2d');

var ctx2 = document.getElementById('myChart2').getContext('2d');

var chart = new Chart(ctx, {
    // The type of chart we want to create
    type: 'line',

    // The data for our dataset
    data: {
        labels: [],
        datasets: [{
            label: "Time taken to mine (microseconds)",
            backgroundColor: 'rgb(255,0, 0)',
            borderColor: 'rgb(0, 255, 0)',
            data: [],
        }]
    },

    // Configuration options go here
    options: {

        
    }
});

var chart2 = new Chart(ctx2, {
    // The type of chart we want to create
    type: 'line',

    // The data for our dataset
    data: {
        labels: [],
        datasets: [{
            label: "Amount transacted in each block",
            backgroundColor: 'rgb(255,255, 0)',
            borderColor: 'rgb(0, 255, 255)',
            data: [],
        }]
    },

    // Configuration options go here
    options: {

        
    }
});


  function addData(chart,label, data) {
      chart.data.labels.push(label);
      chart.data.datasets.forEach((dataset) => {
          dataset.data.push(data);
      });
      chart.update();
  }

    // Configuration options go here
    options: {}
// });

let a = 1
let b = 0;
let c = 0;

channel.on("new_message", payload => {
  b = b + payload.transacted_amt;
  c= c + payload.rew;  
  messagesContainer.html(`Total bitcoins transacted : ${b} BTC`)
  messagesContainer2.html(`Total bitcoins mined : ${c} BTC`)
  addData(chart,a,payload.time_taken)
  addData(chart2,a,payload.transacted_amt)
  a= a + 1
})
