import React from 'react'
import { storiesOf } from '@storybook/react'
import { MemoryRouter } from 'react-router-dom'
import Search from './../src/components/UI/Search/Search'
import SearchWithSuggestions
  from './../src/components/UI/Search/WithSuggestions/WithSuggestions'
import ColorModeComparison from './ColorModeComparison'

storiesOf('Search', module)
  .addDecorator(story => (
    <MemoryRouter initialEntries={['/']}>{story()}</MemoryRouter>
  ))
  .add('Simple', () => (
    <div>
      <ColorModeComparison>
        <Search defaultValue={'Left icon'} />
        <Search iconPosition='right' defaultValue={'Right icon'} />
        <Search />
        <Search iconPosition='right' />
      </ColorModeComparison>
    </div>
  ))
  .add('Suggestions', () => (
    <div>
      <ColorModeComparison>
        <SearchWithSuggestions
          data={[
            'Bibox Token',
            'Bigbom',
            'Binance Coin',
            'BioCoin',
            'BitBay',
            'bitcoin'
          ]}
          maxSuggestions={5}
        />
      </ColorModeComparison>
    </div>
  ))
