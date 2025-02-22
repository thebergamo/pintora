import { GraphicsIR } from '@pintora/core'
import { IRenderer } from './type'
import { makeRenderer, RendererType, BaseRenderer, rendererRegistry } from './renderers'

export type RenderOptions = {
  container: HTMLElement
  renderer?: RendererType
  onRender?(renderer: IRenderer): void
}

export { BaseRenderer, rendererRegistry, IRenderer }

export function render(ir: GraphicsIR, opts: RenderOptions) {
  // console.log('TBD, render', ir)
  const renderer = makeRenderer(ir, opts.renderer).setContainer(opts.container)

  renderer.render()

  if (opts.onRender) {
    opts.onRender(renderer)
  }
}
