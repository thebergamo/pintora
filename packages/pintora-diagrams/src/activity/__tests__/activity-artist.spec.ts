import pintora from '@pintora/core'
import { EXAMPLES, stripStartEmptyLines } from '@pintora/test-shared'
import { testDraw, prepareDiagramConfig, stripDrawResultForSnapshot } from '../../__tests__/test-util'
import { activityDiagram } from '../index'

describe('activity-artist', () => {
  beforeAll(() => {
    prepareDiagramConfig()
    pintora.diagramRegistry.registerDiagram('activityDiagram', activityDiagram)
  })

  it('can draw', () => {
    expect(testDraw(EXAMPLES.activity.code).graphicIR.mark).toBeTruthy()
  })

  it('draw fork', () => {
    const code = stripStartEmptyLines(`
    activityDiagram
    start
    if (multiprocessor?) then
      fork
        :Action 1;
      forkagain
        :Action 2;
      endfork
      else (monoproc)
        :Action 1;
        :Action 2;
      endif
    end
    `)
    expect(stripDrawResultForSnapshot(testDraw(code))).toMatchSnapshot()
  })
})
