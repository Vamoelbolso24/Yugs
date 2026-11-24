-- Machamp
-- Cannot be Normal Summoned/Set. Must first be Special Summoned (from your hand) by Tributing 1 "Machoke" you control.
-- If Summoned this way: You can destroy all face-up monsters your opponent controls whose DEF is lower than this card's ATK.
-- Cannot be destroyed or targeted by your opponent's monster effects.
-- Control of this card cannot change.
-- If this card inflicts battle damage to your opponent or destroys a monster by battle: Inflict 800 damage to your
-- opponent. (Once per battle, even if both happen.)
local s,id=GetID()
function s.initial_effect(c)
	Pokemon.AddNomiSummon(c,1900000109)       -- Tribute 1 Machoke you control
	Pokemon.AddNoControlChange(c)

	local e1=Effect.CreateEffect(c)
	e1:SetDescription(aux.Stringid(id,0))
	e1:SetCategory(CATEGORY_DESTROY)
	e1:SetType(EFFECT_TYPE_SINGLE+EFFECT_TYPE_TRIGGER_O)
	e1:SetCode(EVENT_SPSUMMON_SUCCESS)
	e1:SetCondition(function(e) return Pokemon.IsNomiSummoned(e:GetHandler()) end)
	e1:SetTarget(function(e,tp,eg,ep,ev,re,r,rp,chk)
		local g=Duel.GetMatchingGroup(s.desfilter,tp,0,LOCATION_MZONE,nil,e:GetHandler():GetAttack())
		if chk==0 then return #g>0 end
		Duel.SetOperationInfo(0,CATEGORY_DESTROY,g,#g,0,0)
	end)
	e1:SetOperation(function(e,tp)
		local c=e:GetHandler()
		if not (c:IsRelateToEffect(e) and c:IsFaceup()) then return end
		Duel.Destroy(Duel.GetMatchingGroup(s.desfilter,tp,0,LOCATION_MZONE,nil,c:GetAttack()),REASON_EFFECT)
	end)
	c:RegisterEffect(e1)
	-- Opponent's monster effects can't destroy or target it
	local e2=Effect.CreateEffect(c)
	e2:SetType(EFFECT_TYPE_SINGLE)
	e2:SetProperty(EFFECT_FLAG_SINGLE_RANGE)
	e2:SetRange(LOCATION_MZONE)
	e2:SetCode(EFFECT_INDESTRUCTABLE_EFFECT)
	e2:SetValue(function(e,re) return re:IsMonsterEffect() and re:GetOwnerPlayer()~=e:GetHandlerPlayer() end)
	c:RegisterEffect(e2)
	local e3=e2:Clone()
	e3:SetCode(EFFECT_CANNOT_BE_EFFECT_TARGET)
	c:RegisterEffect(e3)
	-- 800 damage: on battle damage, or on destroying by battle (only once per battle)
	local e4=Effect.CreateEffect(c)
	e4:SetCategory(CATEGORY_DAMAGE)
	e4:SetType(EFFECT_TYPE_SINGLE+EFFECT_TYPE_TRIGGER_F)
	e4:SetCode(EVENT_BATTLE_DAMAGE)
	e4:SetCondition(function(e,tp,eg,ep) return ep==1-tp and e:GetHandler():GetFlagEffect(id)==0 end)
	e4:SetTarget(s.dmgtg)
	e4:SetOperation(s.dmgop)
	c:RegisterEffect(e4)
	local e5=e4:Clone()
	e5:SetCode(EVENT_BATTLE_DESTROYING)
	e5:SetCondition(function(e) return aux.bdcon(e) and e:GetHandler():GetFlagEffect(id)==0 end)
	c:RegisterEffect(e5)
end
s.listed_names={1900000109}
function s.desfilter(c,atk) return c:IsFaceup() and c:GetDefense()<atk end
function s.dmgtg(e,tp,eg,ep,ev,re,r,rp,chk)
	if chk==0 then return true end
	-- mark this battle as used, so the other trigger doesn't also fire
	e:GetHandler():RegisterFlagEffect(id,RESET_EVENT|RESETS_STANDARD|RESET_PHASE|PHASE_DAMAGE,0,1)
	Duel.SetOperationInfo(0,CATEGORY_DAMAGE,nil,0,1-tp,800)
end
function s.dmgop(e,tp) Duel.Damage(1-tp,800,REASON_EFFECT) end
