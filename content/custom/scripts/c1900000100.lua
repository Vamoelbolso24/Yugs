-- Poliwrath
-- Evolution Summon from "Poliwhirl" (hard once per turn).
-- Cannot be destroyed by battle with, or targeted by the effects of, WATER monsters.
-- While "Rain Dance" is on the field, this card gains these effects:
-- * Your opponent cannot target other "Poli" monsters you control for attacks.
-- * Once per turn, during your turn, when a card or effect is activated that targets this card: You can
--   Tribute 1 other "Poli" monster; negate the activation, and if you do, destroy that card.
local s,id=GetID()
function s.initial_effect(c)
	Pokemon.AddEvolutionSummon(c,1900000099)   -- from Poliwhirl
	Pokemon.AddWaterProtection(c)

	local rain=function() return Pokemon.IsOnField(CARD_RAIN_DANCE) end
	-- Other Poli can't be attacked
	local e1=Effect.CreateEffect(c)
	e1:SetType(EFFECT_TYPE_FIELD)
	e1:SetCode(EFFECT_CANNOT_SELECT_BATTLE_TARGET)
	e1:SetRange(LOCATION_MZONE)
	e1:SetTargetRange(0,LOCATION_MZONE)       -- the opponent's attackers...
	e1:SetCondition(rain)
	e1:SetValue(function(e,tc)                 -- ...can't choose these
		return tc:IsFaceup() and tc:IsSetCard(SET_POLI) and tc~=e:GetHandler()
	end)
	c:RegisterEffect(e1)
	-- Negate something targeting it
	local e2=Effect.CreateEffect(c)
	e2:SetDescription(aux.Stringid(id,0))
	e2:SetCategory(CATEGORY_NEGATE+CATEGORY_DESTROY)
	e2:SetType(EFFECT_TYPE_QUICK_O)
	e2:SetCode(EVENT_CHAINING)
	e2:SetRange(LOCATION_MZONE)
	e2:SetProperty(EFFECT_FLAG_DAMAGE_STEP+EFFECT_FLAG_DAMAGE_CAL)
	e2:SetCountLimit(1)
	e2:SetCondition(function(e,tp,eg,ep,ev,re,r,rp)
		local c=e:GetHandler()
		if not (rain() and Duel.IsTurnPlayer(tp) and Duel.IsChainNegatable(ev)) then return false end
		if not re:IsHasProperty(EFFECT_FLAG_CARD_TARGET) then return false end
		local g=Duel.GetChainInfo(ev,CHAININFO_TARGET_CARDS)
		return g and g:IsContains(c)
	end)
	e2:SetCost(function(e,tp,eg,ep,ev,re,r,rp,chk)
		local c=e:GetHandler()
		local f=function(tc) return tc:IsSetCard(SET_POLI) and tc~=c end
		if chk==0 then return Duel.CheckReleaseGroupCost(tp,f,1,false,nil,c) end
		local g=Duel.SelectReleaseGroupCost(tp,f,1,1,false,nil,c)
		Duel.Release(g,REASON_COST)
	end)
	e2:SetTarget(function(e,tp,eg,ep,ev,re,r,rp,chk)
		if chk==0 then return true end
		Duel.SetOperationInfo(0,CATEGORY_NEGATE,eg,1,0,0)
		if re:GetHandler():IsDestructable() and re:GetHandler():IsRelateToEffect(re) then
			Duel.SetOperationInfo(0,CATEGORY_DESTROY,eg,1,0,0)
		end
	end)
	e2:SetOperation(function(e,tp,eg,ep,ev,re,r,rp)
		if Duel.NegateActivation(ev) and re:GetHandler():IsRelateToEffect(re) then
			Duel.Destroy(eg,REASON_EFFECT)
		end
	end)
	c:RegisterEffect(e2)
end
s.listed_names={1900000099,CARD_RAIN_DANCE}
s.listed_series={SET_POLI}
