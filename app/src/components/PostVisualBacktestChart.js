import React from 'react'
import 'chartjs-plugin-annotation'
import { Line } from 'react-chartjs-2'
import './PostVisualBacktestChart.css'

const Color = {
  POSITIVE: 'rgb(48, 157, 129)',
  NEGATIVE: 'rgb(200, 47, 63)'
}

const chartOptions = {
  animation: false,
  legend: {
    display: false
  },
  tooltips: {
    enabled: false
  },
  scales: {
    yAxes: [
      {
        display: false
      }
    ],
    xAxes: [
      {
        id: 'x-axis-0',
        display: false
      }
    ]
  }
}

const datasetOptions = {
  borderColor: 'rgba(255, 193, 7, 1)',
  borderWidth: 1,
  pointRadius: 0,
  fill: false
}

const PostVisualBacktestChart = ({
  history: { historyPrice },
  postUpdatedAt,
  changePriceProp,
  change
}) => {
  const dataset = {
    labels: historyPrice.map(data => data.datetime),
    datasets: [
      {
        data: historyPrice.map(data => data[changePriceProp]),
        ...datasetOptions
      }
    ]
  }

  return (
    <div className='PostVisualBacktestChart'>
      <Line
        options={{
          ...chartOptions,
          annotation: {
            annotations: [
              {
                drawTime: 'afterDatasetsDraw',
                type: 'line',
                mode: 'vertical',
                scaleID: 'x-axis-0',
                value: postUpdatedAt,
                borderColor: change > 0 ? Color.POSITIVE : Color.NEGATIVE,
                borderWidth: 1
              }
            ]
          }
        }}
        data={dataset}
      />
    </div>
  )
}

export default PostVisualBacktestChart
