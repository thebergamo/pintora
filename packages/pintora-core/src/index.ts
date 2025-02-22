import { diagramRegistry } from './diagram-registry'

export * from './type'
import { logger, setLogLevel } from './logger'
import configApi, { PintoraConfig } from './config'

export * from './util'
import { encodeForUrl, decodeCodeInUrl, makeMark, calculateTextDimensions, parseColor, tinycolor } from './util'
import { symbolRegistry, SymbolDef, SymbolStyleAttrs } from './symbol-registry'
import { ConfigParam, interpreteConfigs } from './config-engine'
import { themeRegistry, ITheme } from './themes'
import { DEFAULT_FONT_FAMILY } from './consts'
import * as configEngine from './config-engine'

export {
  logger,
  setLogLevel,
  configApi,
  symbolRegistry,
  SymbolDef,
  SymbolStyleAttrs,
  ConfigParam,
  interpreteConfigs,
  PintoraConfig,
  tinycolor,
  ITheme,
  themeRegistry,
  DEFAULT_FONT_FAMILY,
}

type DrawOptions = {
  onError?(error: Error): void
  config?: PintoraConfig
}

const pintora = {
  configApi,
  diagramRegistry,
  symbolRegistry,
  configEngine,
  themeRegistry,
  parseAndDraw(text: string, opts: DrawOptions) {
    const { onError, config } = opts
    const diagram = diagramRegistry.detectDiagram(text)
    if (!diagram) {
      const errMessage = `[pintora] no diagram detected with input: ${text.slice(0, 30)}`
      logger.warn(errMessage)
      onError && onError(new Error(errMessage))
      return
    }

    diagram.clear()
    const diagramIR = diagram.parser.parse(text)

    let configForArtist = undefined

    if (config && diagram.configKey && (config as any)[diagram.configKey]) {
      configForArtist = (config as any)[diagram.configKey]
    }
    const graphicIR = diagram.artist.draw(diagramIR, configForArtist)

    return {
      diagramIR,
      graphicIR,
    }
  },
  util: {
    encodeForUrl,
    decodeCodeInUrl,
    makeMark,
    calculateTextDimensions,
    parseColor,
    tinycolor,
  },
}

export default pintora
