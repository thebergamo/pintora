import { Mark, Bounds, Point } from '@pintora/core'
import { Graph, GraphOptions } from '@pintora/graphlib'
import { GraphData } from '@pintora/dagre/dist/types/type'

export type LayoutGraph = Graph<LayoutNodeOption, any, GraphData>

export function createLayoutGraph(opts?: GraphOptions) {
  return new Graph(opts)
}

type DagreGraphOpts = {
  marginx?: number
  marginy?: number
}

type GetGraphBoundsOpts = {
  filterNode?(node: LayoutNode): boolean
  startLeft?: number
  startTop?: number
}

export function getGraphBounds(g: LayoutGraph, opts: GetGraphBoundsOpts = {}): Bounds {
  let left = opts.startLeft || 0
  let right = 0
  let top = opts.startTop || 0
  let bottom = 0
  g.nodes().forEach(k => {
    const node: LayoutNode = g.node(k) as any
    if (!node) return
    if (opts.filterNode && !opts.filterNode(node)) return

    left = Math.min(node.outerLeft || node.x, left)
    const width = node.outerWidth || node.width
    // assuming the node is positioned with anchor point centered
    right = Math.max(node.outerRight || node.x + width / 2, right)
    top = Math.min(node.outerTop || node.y, top)
    const height = node.outerHeight || node.height
    bottom = Math.max(node.outerBottom || node.y + height / 2, bottom)
  })

  const graphOpts: DagreGraphOpts = g.graph() as any
  const marginx = graphOpts.marginx || 0
  const marginy = graphOpts.marginy || 0

  return {
    left,
    right,
    top,
    bottom,
    width: right - left + marginx,
    height: bottom - top + marginy,
  }
}
export interface LayoutNodeOption {
  width?: number
  height?: number
  id?: string
  mark?: Mark
  outerWidth?: number
  outerHeight?: number
  outerLeft?: number
  outerRight?: number
  outerTop?: number
  outerBottom?: number
  marginl?: number
  marginr?: number
  /**
   * Sometimes we need a dummy box to hold content area for a given node,
   *   for a node, this is it's dummy box's id.
   */
  dummyBoxId?: string
  /** if this is a dummy node */
  isDummy?: boolean
  onLayout?(data: LayoutNode): void
}

export interface LayoutNode extends LayoutNodeOption {
  id?: string
  mark?: Mark
  name?: string // debug
  width: number
  height: number
  x: number
  y: number
}

export type LayoutEdge<T> = {
  points: Point[]
} & T

export function isSubgraph(g: LayoutGraph, id: string) {
  return Boolean(g.children(id).length)
}

/**
 * call `onLayout` on each nodeData
 */
export function adjustEntities(graph: LayoutGraph) {
  graph.nodes().forEach(function (v) {
    const nodeData: LayoutNode = graph.node(v) as any
    if (nodeData) {
      // console.log('adjustEntities, graph node: ', nodeData)
      if (nodeData.onLayout) {
        nodeData.onLayout(nodeData)
      }
    }
  })
}

/** is topdown */
export function isGraphVertical(g: LayoutGraph) {
  return g.graph().rankdir === 'TB'
}
